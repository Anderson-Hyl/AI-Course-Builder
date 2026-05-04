import ComposableArchitecture
import Foundation
import LearningModels
import LearningRepository

/// Session Workspace — the block-by-block lesson player. Renders one
/// `SessionBlock` at a time via `LessonRendering.BlockView` and walks
/// the learner through the session with Back / Next / Done controls.
///
/// **Out of scope this pass**: attempt capture, scoring, tutor panel,
/// "previous answers" recall. The Submit/Run buttons inside individual
/// block renderers are still disabled with their existing TODOs; this
/// feature only owns navigation through the ordered block list.
@Reducer
public struct SessionWorkspaceFeature {
    @ObservableState
    public struct State: Equatable {
        public let sessionID: Session.ID
        public var session: Session?
        public var blocks: [SessionBlock] = []
        public var currentBlockIndex: Int = 0
        public var loadFailure: String?

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
        case loaded(session: Session?, blocks: [SessionBlock])
        case loadFailed(String)
        case nextTapped
        case previousTapped
        case doneTapped
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
                        await send(.loaded(session: session, blocks: blocks))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case .loaded(let session, let blocks):
                state.session = session
                state.blocks = blocks
                state.currentBlockIndex = 0
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

            case .delegate:
                return .none
            }
        }
    }
}
