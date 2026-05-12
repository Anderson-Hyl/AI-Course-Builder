import AdaptationEngine
import ComposableArchitecture
import EvaluationEngine
import Foundation
import LearningModels
import LearningRepository
import TutorEngine

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
        /// Whether the right-edge AI Tutor slide-over is visible. Default
        /// `false` so focus mode reads distraction-free.
        public var tutorOpen: Bool = false
        /// Conversation history for the tutor panel. Persists for the
        /// SessionWorkspace's lifetime (across block navigation + panel
        /// toggles) — resets when the workspace is dismissed. The
        /// context handed to `TutorEngine.ask` is rebuilt per send, so
        /// the model always sees the learner's CURRENT block even when
        /// the history started on a different one.
        public var tutorTurns: IdentifiedArrayOf<TutorTurn> = []
        /// Composer text the learner is typing. Cleared on send; kept
        /// across panel toggles so a half-typed question survives a
        /// close + reopen.
        public var tutorComposerDraft: String = ""
        /// True while a tutor response is in flight. Used to disable
        /// the send button + suggested prompts and to drive the
        /// "thinking" indicator while we wait for the first chunk.
        public var tutorStreaming: Bool = false
        /// Last tutor error, surfaced inline below the conversation
        /// with a retry button. Cleared on the next successful send.
        public var tutorError: String?

        /// Tracks the post-session adaptation lifecycle. `.idle` until the
        /// learner taps Done; `.running` while `AdaptationEngine.adapt`
        /// is in flight; `.summary` after success — the workspace pauses
        /// on the digest card until the learner taps Continue; `.failed`
        /// if the engine threw (the workspace stays open with an error
        /// overlay so the learner can retry or skip).
        public var adaptation: AdaptationStatus = .idle
        /// Mirrors the `.summary` payload for callers that need the
        /// digest without pattern-matching the enum (e.g. read-only UI
        /// chrome). Set at the same moment `adaptation` flips to
        /// `.summary` and cleared on dismiss.
        public var adaptationSummary: AdaptationSummary?

        public enum AdaptationStatus: Equatable {
            case idle
            case running
            case summary(AdaptationSummary)
            case failed(String)

            /// True when the lesson surface should be inert (Done button
            /// disabled, etc.). Both `.running` and `.summary` block
            /// re-firing adaptation or scrolling back through blocks
            /// while the workspace is in its "after the session"
            /// terminal flow.
            public var blocksLessonInteraction: Bool {
                switch self {
                case .running, .summary: true
                case .idle, .failed: false
                }
            }
        }

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
        /// Escape paths (breadcrumb, "Exit session" pill) that bypass
        /// adaptation. The learner is leaving without completing the
        /// session, so we just dismiss without scoring or adapting.
        case exitTapped
        /// Adaptation completed successfully — store the summary and
        /// pause on the digest card. The workspace dismisses only after
        /// the learner taps Continue (`continueAfterSummaryTapped`).
        case adaptationCompleted(AdaptationSummary)
        /// Adaptation threw. The workspace stays open with the error
        /// overlay; learner picks Retry or Skip.
        case adaptationFailed(String)
        /// Retry button on the adaptation error overlay.
        case adaptationRetryTapped
        /// Skip button on the adaptation error overlay — dismisses the
        /// workspace without re-running adaptation. Session stays in
        /// whatever status it had.
        case adaptationSkipTapped
        /// Continue button on the adaptation summary card — dismisses
        /// the workspace and returns the learner to Course Home. The
        /// session is already marked completed at this point.
        case continueAfterSummaryTapped
        /// Topbar AI Tutor button / slide-over close-X.
        case tutorToggled
        /// Per-keystroke composer update.
        case tutorComposerChanged(String)
        /// Composer "send" affordance (button or return key).
        case tutorSendTapped
        /// One of the suggested-prompt chips below the empty state.
        case tutorSuggestedTapped(String)
        /// Streaming chunk from `TutorEngine.ask`. `text` is cumulative.
        case tutorChunk(turnID: UUID, text: String)
        /// `TutorEngine.ask` finished without error.
        case tutorStreamFinished(turnID: UUID)
        /// `TutorEngine.ask` threw. The empty placeholder tutor turn is
        /// removed and `tutorError` is set so the view can surface a
        /// retry affordance.
        case tutorStreamFailed(turnID: UUID, message: String)
        /// User tapped the retry button in the inline error bubble.
        /// Resends the last user turn against the current context.
        case tutorRetryTapped
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
    @Dependency(\.tutorEngine) var tutorEngine
    @Dependency(\.adaptationEngine) var adaptationEngine
    @Dependency(\.uuid) var uuid

    private enum CancelID: Hashable {
        case tutorStream
        case adaptation
    }

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
                // Re-entrancy guard: a slow LLM round-trip + impatient
                // double-taps shouldn't fire two adaptation requests.
                if state.adaptation == .running { return .none }
                state.tutorStreaming = false
                state.adaptation = .running
                let id = state.sessionID
                return .merge(
                    .cancel(id: CancelID.tutorStream),
                    .run { [adaptationEngine] send in
                        do {
                            let summary = try await adaptationEngine.adapt(id)
                            await send(.adaptationCompleted(summary))
                        } catch is CancellationError {
                            // Workspace dismissed mid-adapt; nothing to surface.
                        } catch let error as AdaptationEngineError {
                            await send(.adaptationFailed(error.localizedDescription))
                        } catch {
                            await send(.adaptationFailed(error.localizedDescription))
                        }
                    }
                    .cancellable(id: CancelID.adaptation, cancelInFlight: true)
                )

            case .exitTapped:
                state.tutorStreaming = false
                return .merge(
                    .cancel(id: CancelID.tutorStream),
                    .cancel(id: CancelID.adaptation),
                    .send(.delegate(.dismiss))
                )

            case .adaptationCompleted(let summary):
                state.adaptationSummary = summary
                state.adaptation = .summary(summary)
                return .none

            case .continueAfterSummaryTapped:
                state.adaptation = .idle
                return .send(.delegate(.dismiss))

            case .adaptationFailed(let message):
                state.adaptation = .failed(message)
                return .none

            case .adaptationRetryTapped:
                if state.adaptation == .running { return .none }
                state.adaptation = .running
                let id = state.sessionID
                return .run { [adaptationEngine] send in
                    do {
                        let summary = try await adaptationEngine.adapt(id)
                        await send(.adaptationCompleted(summary))
                    } catch is CancellationError {
                        // Cancelled by a second tap or dismiss.
                    } catch let error as AdaptationEngineError {
                        await send(.adaptationFailed(error.localizedDescription))
                    } catch {
                        await send(.adaptationFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.adaptation, cancelInFlight: true)

            case .adaptationSkipTapped:
                state.adaptation = .idle
                return .merge(
                    .cancel(id: CancelID.adaptation),
                    .send(.delegate(.dismiss))
                )

            case .tutorToggled:
                state.tutorOpen.toggle()
                return .none

            case .tutorComposerChanged(let text):
                state.tutorComposerDraft = text
                return .none

            case .tutorSendTapped:
                return startTutorTurn(text: state.tutorComposerDraft, state: &state)

            case .tutorSuggestedTapped(let prompt):
                return startTutorTurn(text: prompt, state: &state)

            case .tutorChunk(let turnID, let text):
                if let index = state.tutorTurns.index(id: turnID) {
                    state.tutorTurns[index].text = text
                }
                return .none

            case .tutorStreamFinished:
                state.tutorStreaming = false
                return .none

            case .tutorStreamFailed(let turnID, let message):
                state.tutorStreaming = false
                state.tutorError = message
                state.tutorTurns.remove(id: turnID)
                return .none

            case .tutorRetryTapped:
                state.tutorError = nil
                guard let lastUser = state.tutorTurns.reversed().first(where: { $0.role == .user })
                else { return .none }
                while let last = state.tutorTurns.last, last.id != lastUser.id {
                    state.tutorTurns.removeLast()
                }
                let tutorTurn = TutorTurn(id: uuid(), role: .tutor, text: "")
                state.tutorTurns.append(tutorTurn)
                state.tutorStreaming = true
                let turns = Array(state.tutorTurns)
                let context = Self.makeContext(state: state)
                return streamTutor(turns: turns, context: context, targetID: tutorTurn.id)

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

    private func startTutorTurn(text rawText: String, state: inout State) -> Effect<Action> {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .none }
        let userTurn = TutorTurn(id: uuid(), role: .user, text: text)
        let tutorTurn = TutorTurn(id: uuid(), role: .tutor, text: "")
        state.tutorTurns.append(userTurn)
        state.tutorTurns.append(tutorTurn)
        state.tutorComposerDraft = ""
        state.tutorError = nil
        state.tutorStreaming = true
        let turns = Array(state.tutorTurns)
        let context = Self.makeContext(state: state)
        return streamTutor(turns: turns, context: context, targetID: tutorTurn.id)
    }

    private func streamTutor(
        turns: [TutorTurn],
        context: TutorContext,
        targetID: UUID
    ) -> Effect<Action> {
        .run { [tutorEngine] send in
            do {
                for try await chunk in tutorEngine.ask(turns, context) {
                    switch chunk {
                    case .text(let cumulative):
                        await send(.tutorChunk(turnID: targetID, text: cumulative))
                    case .done:
                        await send(.tutorStreamFinished(turnID: targetID))
                    }
                }
            } catch is CancellationError {
                // Stream was cancelled by a newer send or workspace dismiss —
                // don't surface as a failure.
            } catch {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                await send(.tutorStreamFailed(turnID: targetID, message: message))
            }
        }
        .cancellable(id: CancelID.tutorStream, cancelInFlight: true)
    }

    private static func makeContext(state: State) -> TutorContext {
        let position: String
        if state.blocks.isEmpty {
            position = "(session still loading)"
        } else {
            position = "Block \(state.currentBlockIndex + 1) of \(state.blocks.count)"
        }
        return TutorContext(
            sessionTitle: state.session?.title ?? "Session",
            sessionObjective: state.session?.objective ?? "",
            currentBlockKind: state.currentBlock?.kind,
            currentBlockPayloadJSON: state.currentBlock?.payloadJSON,
            blockPositionDescription: position
        )
    }
}
