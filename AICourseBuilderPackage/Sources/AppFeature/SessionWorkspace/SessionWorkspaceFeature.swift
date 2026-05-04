import ComposableArchitecture
import EvaluationEngine
import Foundation
import LearningModels
import LearningRepository

/// Session Workspace — the block-by-block lesson player. Renders one
/// `SessionBlock` at a time via `LessonRendering.BlockView` and walks
/// the learner through the session with Back / Next / Done controls.
///
/// **Attempt capture is live for `multiple_choice`.** Selecting an option
/// records an `Attempt` with a deterministic verdict from
/// `EvaluationEngine.evaluateMultipleChoice` and persists it through
/// `LearningRepository.recordAttempt`. On re-entry the latest attempt
/// per block is rehydrated so the user sees their last selection +
/// correctness instead of a pristine question.
///
/// Other interactive kinds (`short_answer`, `code_exercise`, `reflection`,
/// `checkpoint`) still no-op on submit pending the LLM-as-judge path —
/// they need `expectedAnswer` / rubric evaluation that lands with the
/// first ChatClient pass.
@Reducer
public struct SessionWorkspaceFeature {
    @ObservableState
    public struct State: Equatable {
        public let sessionID: Session.ID
        public var session: Session?
        public var blocks: [SessionBlock] = []
        public var currentBlockIndex: Int = 0
        public var loadFailure: String?
        /// Latest persisted attempt per block, keyed by `SessionBlock.ID`.
        /// Loaded on `.onAppear`; updated in place after each submit.
        public var attempts: [SessionBlock.ID: Attempt] = [:]

        public init(sessionID: Session.ID) {
            self.sessionID = sessionID
        }

        public var currentBlock: SessionBlock? {
            guard blocks.indices.contains(currentBlockIndex) else { return nil }
            return blocks[currentBlockIndex]
        }

        public var canGoBack: Bool {
            currentBlockIndex > 0
        }

        public var canGoForward: Bool {
            !blocks.isEmpty && currentBlockIndex < blocks.count - 1
        }

        public var isFinalBlock: Bool {
            !blocks.isEmpty && currentBlockIndex == blocks.count - 1
        }
    }

    public enum Action {
        case onAppear
        case loaded(session: Session?, blocks: [SessionBlock], attempts: [SessionBlock.ID: Attempt])
        case loadFailed(String)
        case nextTapped
        case previousTapped
        case doneTapped
        /// User picked an option in a `multiple_choice` block. The
        /// reducer evaluates deterministically + persists; the render
        /// updates from the persisted `Attempt` so the UI shows the
        /// same shape we'll see after relaunch.
        case multipleChoiceSelected(blockID: SessionBlock.ID, index: Int)
        case attemptRecorded(Attempt)
        case attemptFailed(String)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismiss
        }
    }

    @Dependency(\.learningRepository) var repository

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let id = state.sessionID
                return .run { [repository] send in
                    do {
                        let session = try await repository.fetchSession(id: id)
                        let blocks = try await repository.fetchBlocks(forSessionID: id)
                        let attempts = try await repository.fetchLatestAttempts(forSessionID: id)
                        await send(.loaded(session: session, blocks: blocks, attempts: attempts))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case .loaded(let session, let blocks, let attempts):
                state.session = session
                state.blocks = blocks
                state.currentBlockIndex = 0
                state.attempts = attempts
                state.loadFailure = nil
                return .none

            case .loadFailed(let message):
                state.loadFailure = message
                return .none

            case .nextTapped:
                if state.canGoForward {
                    state.currentBlockIndex += 1
                }
                return .none

            case .previousTapped:
                if state.canGoBack {
                    state.currentBlockIndex -= 1
                }
                return .none

            case .doneTapped:
                return .send(.delegate(.dismiss))

            case .multipleChoiceSelected(let blockID, let index):
                guard let block = state.blocks.first(where: { $0.id == blockID }),
                      block.kind == BlockKind.multipleChoice,
                      let payloadData = block.payloadJSON.data(using: .utf8),
                      let payload = try? JSONDecoder().decode(BlockPayload.MultipleChoice.self, from: payloadData),
                      payload.options.indices.contains(index)
                else {
                    return .none
                }
                let input = AttemptInput.MultipleChoice(selectedIndex: index)
                let result = EvaluationEngine.evaluateMultipleChoice(input: input, against: payload)
                let inputJSON: String
                let resultJSON: String
                do {
                    inputJSON = try Self.encodeJSON(input)
                    resultJSON = try Self.encodeJSON(result)
                } catch {
                    state.loadFailure = error.localizedDescription
                    return .none
                }
                // Optimistic in-memory attempt so the option highlight +
                // correctness badge appear on the same frame as the tap.
                // The async write reconciles the row (real id + createdAt)
                // via `.attemptRecorded`.
                let optimistic = Attempt(
                    id: UUID(),
                    blockID: blockID,
                    kind: BlockKind.multipleChoice,
                    inputJSON: inputJSON,
                    resultJSON: resultJSON,
                    scoredAt: Date(),
                    createdAt: Date()
                )
                state.attempts[blockID] = optimistic
                return .run { [repository] send in
                    do {
                        let attemptID = try await repository.recordAttempt(
                            blockID: blockID,
                            kind: BlockKind.multipleChoice,
                            inputJSON: inputJSON,
                            resultJSON: resultJSON
                        )
                        if let saved = try await repository.fetchLatestAttempt(forBlockID: blockID),
                           saved.id == attemptID
                        {
                            await send(.attemptRecorded(saved))
                        }
                    } catch {
                        await send(.attemptFailed(error.localizedDescription))
                    }
                }

            case .attemptRecorded(let attempt):
                state.attempts[attempt.blockID] = attempt
                return .none

            case .attemptFailed(let message):
                state.loadFailure = message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
