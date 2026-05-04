import ComposableArchitecture
import Foundation
import LearningModels
import LearningRepository

/// Home Dashboard — the first screen the user sees after Goal Intake
/// completes. Lists the seeded program's stage / sprint / sessions and
/// hands a session ID up to `AppFeature` when the user taps a card.
///
/// State lives in `AppFeature` until needed: parent populates `program`
/// after `installDemoProgram` finishes (or after relaunch finds an
/// existing program), then sends `.onAppear(programID:)` here, which
/// loads the rest of the tree from the repository.
@Reducer
public struct HomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var goal: LearningGoal?
        public var program: ProgramBlueprint?
        public var stage: Stage?
        public var sprint: Sprint?
        public var sessions: [Session] = []
        public var loadFailure: String?

        public init() {}
    }

    public enum Action {
        /// Parent has assigned `goal` + `program`; load stage / sprint /
        /// sessions from the repository.
        case onAppear(programID: ProgramBlueprint.ID)
        case loaded(stage: Stage?, sprint: Sprint?, sessions: [Session])
        case loadFailed(String)
        case sessionTapped(Session.ID)
        case resetTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case sessionTapped(Session.ID)
            case resetTapped
        }
    }

    @Dependency(\.learningRepository) var repository

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear(let programID):
                return .run { [repository] send in
                    do {
                        let stages = try await repository.fetchStages(forProgramID: programID)
                        let stage = stages.first
                        let sprint: Sprint? = if let stage {
                            try await repository.fetchSprints(forStageID: stage.id).first
                        } else {
                            nil
                        }
                        let sessions = try await repository.fetchSessions(forProgramID: programID)
                        await send(.loaded(stage: stage, sprint: sprint, sessions: sessions))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case .loaded(let stage, let sprint, let sessions):
                state.stage = stage
                state.sprint = sprint
                state.sessions = sessions
                state.loadFailure = nil
                return .none

            case .loadFailed(let message):
                state.loadFailure = message
                return .none

            case .sessionTapped(let id):
                return .send(.delegate(.sessionTapped(id)))

            case .resetTapped:
                return .send(.delegate(.resetTapped))

            case .delegate:
                return .none
            }
        }
    }
}
