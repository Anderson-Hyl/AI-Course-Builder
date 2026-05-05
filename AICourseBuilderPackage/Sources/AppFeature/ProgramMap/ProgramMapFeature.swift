import ComposableArchitecture
import Foundation
import LearningModels
import LearningRepository

/// Program Map — the second sidebar destination. Shows the full stage
/// list (current stage expanded with session rows + milestone track,
/// future stages collapsed to lock rows) plus a graduation goal card.
///
/// Mirrors `HomeFeature`'s data shape: parent `AppFeature` populates
/// `goal` + `program` + `profile` after planning completes, then
/// `.onAppear(programID:)` here loads the rest of the tree.
@Reducer
public struct ProgramMapFeature {
    @ObservableState
    public struct State: Equatable {
        public var profile: LearnerProfile?
        public var goal: LearningGoal?
        public var program: ProgramBlueprint?
        public var stages: [Stage] = []
        /// Sessions grouped by `Stage.ID`. Locked stages hold an empty
        /// array — we render a compact lock row, not a session list.
        public var sessionsByStage: [Stage.ID: [Session]] = [:]
        public var loadFailure: String?

        public init() {}

        /// First non-completed stage. Falls through to the last stage so
        /// the path always has a "current" anchor (mirrors HomeFeature's
        /// `todaysSession` fallback).
        public var currentStageID: Stage.ID? {
            stages.first(where: { $0.status != Stage.Status.completed })?.id
                ?? stages.last?.id
        }

        public func sessions(for stageID: Stage.ID) -> [Session] {
            sessionsByStage[stageID] ?? []
        }

        public func completedSessions(for stageID: Stage.ID) -> Int {
            sessions(for: stageID).filter { $0.status == Session.Status.completed }.count
        }
    }

    public enum Action {
        case onAppear(programID: ProgramBlueprint.ID)
        case loaded(stages: [Stage], sessionsByStage: [Stage.ID: [Session]])
        case loadFailed(String)
        case sessionTapped(Session.ID)
        case viewAsListTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case sessionTapped(Session.ID)
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
                        var byStage: [Stage.ID: [Session]] = [:]
                        for stage in stages {
                            let sprints = try await repository.fetchSprints(forStageID: stage.id)
                            var sessions: [Session] = []
                            for sprint in sprints {
                                let part = try await repository.fetchSessions(forSprintID: sprint.id)
                                sessions.append(contentsOf: part)
                            }
                            byStage[stage.id] = sessions
                        }
                        await send(.loaded(stages: stages, sessionsByStage: byStage))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case .loaded(let stages, let sessionsByStage):
                state.stages = stages
                state.sessionsByStage = sessionsByStage
                state.loadFailure = nil
                return .none

            case .loadFailed(let message):
                state.loadFailure = message
                return .none

            case .sessionTapped(let id):
                return .send(.delegate(.sessionTapped(id)))

            case .viewAsListTapped:
                // No-op for now — design board shows a "View as List"
                // affordance; the alternate layout ships in a later pass.
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
