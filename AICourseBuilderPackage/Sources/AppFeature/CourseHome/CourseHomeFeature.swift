import ComposableArchitecture
import Foundation
import LearningModels
import LearningRepository

/// Course Home — the screen the user lands on after picking a course
/// from Library. Merges what `HomeFeature` (Today's session) and
/// `ProgramMapFeature` (the full stage tree) used to render separately
/// in App Structure v1.
///
/// State shape inherits from `ProgramMapFeature` (load the whole tree
/// keyed by stage so the timeline can render every stage at once) and
/// adds the `todaysSession` heuristic from `HomeFeature` for the Today
/// hero on the right rail.
///
/// Parent `AppFeature` populates `profile` / `goal` / `program` after
/// the user enters a course (via `.courseSelected` → planning completes)
/// then sends `.onAppear(programID:)` to load the rest.
@Reducer
public struct CourseHomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var profile: LearnerProfile?
        public var goal: LearningGoal?
        public var program: ProgramBlueprint?
        public var stages: [Stage] = []
        /// Sessions grouped by `Stage.ID`. Locked stages hold an empty
        /// array — the timeline renders a lock card, not a session list.
        public var sessionsByStage: [Stage.ID: [Session]] = [:]
        public var loadFailure: String?

        public init() {}

        /// First non-completed stage. Falls through to the last stage so
        /// the timeline always has a "current" anchor.
        public var currentStageID: Stage.ID? {
            stages.first(where: { $0.status != Stage.Status.completed })?.id
                ?? stages.last?.id
        }

        public var currentStage: Stage? {
            guard let id = currentStageID else { return nil }
            return stages.first(where: { $0.id == id })
        }

        /// Today's session — first non-completed session in the current
        /// stage's session list. Falls through to last so the Continue
        /// affordance never disappears, mirroring HomeFeature's behavior.
        public var todaysSession: Session? {
            guard let stageID = currentStageID else { return nil }
            let stageSessions = sessionsByStage[stageID] ?? []
            return stageSessions.first(where: { $0.status != Session.Status.completed })
                ?? stageSessions.last
        }

        public var allSessions: [Session] {
            stages.flatMap { sessionsByStage[$0.id] ?? [] }
        }

        public var completedSessionsCount: Int {
            allSessions.filter { $0.status == Session.Status.completed }.count
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
        case returnToLibraryTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case sessionTapped(Session.ID)
            case returnToLibraryRequested
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

            case .returnToLibraryTapped:
                return .send(.delegate(.returnToLibraryRequested))

            case .delegate:
                return .none
            }
        }
    }
}
