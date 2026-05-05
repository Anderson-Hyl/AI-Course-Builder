import ChatClients
import ComposableArchitecture
import Foundation
import LearningModels
import LearningRepository
import PlanningEngine

/// Top-level coordinator. Owns the bootstrap path (ensure a `LearnerProfile`
/// exists, fetch any active `LearningGoal`, install or recover the demo
/// program) and the root navigation state. Routes between Goal Intake,
/// the Home Dashboard, and the Session Workspace destination.
@Reducer
public struct AppFeature {
    @Reducer
    public enum Destination {
        case sessionWorkspace(SessionWorkspaceFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var isBootstrapping: Bool = true
        public var profile: LearnerProfile?
        public var currentGoal: LearningGoal?
        public var currentProgram: ProgramBlueprint?
        public var goalIntake: GoalIntakeFeature.State = .init()
        public var home: HomeFeature.State = .init()
        @Presents public var destination: Destination.State?

        /// True while `PlanningEngine.generateBlueprint` is in flight.
        /// `AppView` swaps the root surface to `PlanningProgressView`
        /// for as long as this is set.
        public var isPlanning: Bool = false
        /// Last planning failure. `AppView` shows `PlanningErrorView`
        /// when non-nil; `.missingAPIKey` auto-opens the key sheet.
        public var planningError: PlanningEngineError?
        /// API-key entry sheet, presented from Goal Intake's gear icon
        /// or auto-presented after `.missingAPIKey`.
        @Presents public var apiKeySheet: APIKeySheetFeature.State?

        public init() {}
    }

    public enum Action {
        case onAppear
        case bootstrapCompleted(profile: LearnerProfile, goal: LearningGoal?)
        case bootstrapFailed(String)
        case goalIntake(GoalIntakeFeature.Action)
        case home(HomeFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        /// Fired by the app-level observer after `createGoal` commits.
        case goalCreated(LearningGoal.ID)
        /// Fired after `deleteGoal` commits — returns the user to Goal Intake.
        case goalReset
        /// Internal: install (idempotent) + load the program for the
        /// current goal, then transition the user to Home Dashboard.
        case loadProgramForGoal(LearningGoal.ID)
        /// Internal: program row finished loading — wire it into Home and
        /// kick off the home loader.
        case programLoaded(ProgramBlueprint)
        /// Internal: surfaces error state when program install/load fails.
        case programLoadFailed(String)
        /// Fired by the app-level observer after a program write commits.
        /// The `loadProgramForGoal` flow drives the v1 path; this hook
        /// stays here for engine-driven writes that arrive in later passes.
        case programCreated(ProgramBlueprint.ID, goalID: UUID)
        /// Fired by the app-level observer after sessions change. Drives
        /// a Home reload when the change targets the active program.
        case sessionsChanged(programID: UUID)
        case resetTapped

        // MARK: - Planning
        case planningStarted
        case planningCompleted(ProgramBlueprint)
        case planningFailed(PlanningEngineError)
        case retryPlanningTapped
        case useDemoFallbackTapped
        case dismissPlanningError

        // MARK: - API key sheet
        case openAPIKeySheet
        case apiKeySheet(PresentationAction<APIKeySheetFeature.Action>)
    }

    public init() {}

    @Dependency(\.learningRepository) var repository
    @Dependency(\.planningEngine) var planningEngine

    public var body: some ReducerOf<Self> {
        Scope(state: \.goalIntake, action: \.goalIntake) {
            GoalIntakeFeature()
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.isBootstrapping else { return .none }
                return .run { [repository] send in
                    do {
                        let profile = try await repository.ensureCurrentProfile()
                        let goal = try await repository.fetchActiveGoal()
                        await send(.bootstrapCompleted(profile: profile, goal: goal))
                    } catch {
                        await send(.bootstrapFailed(error.localizedDescription))
                    }
                }

            case .bootstrapCompleted(let profile, let goal):
                state.isBootstrapping = false
                state.profile = profile
                state.currentGoal = goal
                state.home.profile = profile
                state.home.goal = goal
                // Seed the form with profile defaults so re-opening Goal
                // Intake (after a Reset) starts from where the user left off.
                state.goalIntake.startingLevel = profile.startingLevel
                state.goalIntake.weeklyTimeBudgetHours = profile.weeklyTimeBudgetHours
                state.goalIntake.learningStyles = profile.learningStyles
                state.goalIntake.targetOutcome = profile.targetOutcome ?? ""
                if let goal {
                    return .send(.loadProgramForGoal(goal.id))
                }
                return .none

            case .bootstrapFailed:
                state.isBootstrapping = false
                return .none

            case .goalIntake(.delegate(.submitTapped)):
                guard let profileID = state.profile?.id else { return .none }
                let intake = state.goalIntake
                return .run { [repository] _ in
                    try await repository.updateProfile(
                        id: profileID,
                        startingLevel: intake.startingLevel,
                        weeklyTimeBudgetHours: intake.weeklyTimeBudgetHours,
                        learningStyles: intake.learningStyles,
                        targetOutcome: intake.targetOutcome.isEmpty ? .some(nil) : .some(intake.targetOutcome)
                    )
                    _ = try await repository.createGoal(
                        profileID: profileID,
                        text: intake.goalText
                    )
                    // Observer dispatches `.goalCreated`.
                }

            case .goalIntake(.delegate(.openAPIKeySheet)):
                return .send(.openAPIKeySheet)

            case .goalIntake:
                return .none

            case .goalCreated(let id):
                return .run { [repository] send in
                    let goals = try await repository.fetchAllGoals()
                    if let row = goals.first(where: { $0.id == id }) {
                        let profile = try await repository.ensureCurrentProfile()
                        await send(.bootstrapCompleted(profile: profile, goal: row))
                    }
                }

            case .loadProgramForGoal(let goalID):
                guard let profileID = state.profile?.id else { return .none }
                state.isPlanning = true
                state.planningError = nil
                return .run { [planningEngine, repository] send in
                    do {
                        // Idempotent: returns existing program if one is
                        // already on disk for this goal, otherwise drives
                        // the LLM call + persists via the repository.
                        let programID = try await planningEngine.generateBlueprint(
                            goalID, profileID, false
                        )
                        guard
                            let program = try await repository.fetchProgram(forGoalID: goalID),
                            program.id == programID
                        else {
                            await send(.planningFailed(.translationFailed(
                                underlying: LearningRepositoryError.programNotFound(programID)
                            )))
                            return
                        }
                        await send(.planningCompleted(program))
                    } catch let error as PlanningEngineError {
                        await send(.planningFailed(error))
                    } catch is CancellationError {
                        await send(.planningFailed(.cancelled))
                    } catch {
                        await send(.planningFailed(.network(error.localizedDescription)))
                    }
                }

            case .planningStarted:
                state.isPlanning = true
                state.planningError = nil
                return .none

            case .planningCompleted(let program):
                state.isPlanning = false
                state.planningError = nil
                state.currentProgram = program
                state.home.goal = state.currentGoal
                state.home.program = program
                return .send(.home(.onAppear(programID: program.id)))

            case .planningFailed(let error):
                state.isPlanning = false
                state.planningError = error
                if case .missingAPIKey = error, state.apiKeySheet == nil {
                    state.apiKeySheet = APIKeySheetFeature.State()
                }
                return .none

            case .retryPlanningTapped:
                guard let goalID = state.currentGoal?.id else { return .none }
                state.planningError = nil
                return .send(.loadProgramForGoal(goalID))

            case .useDemoFallbackTapped:
                guard let goalID = state.currentGoal?.id else { return .none }
                state.planningError = nil
                state.isPlanning = true
                return .run { [repository] send in
                    do {
                        _ = try await repository.installDemoProgram(goalID: goalID)
                        if let program = try await repository.fetchProgram(forGoalID: goalID) {
                            await send(.planningCompleted(program))
                        } else {
                            await send(.planningFailed(.translationFailed(
                                underlying: LearningRepositoryError.profileBootstrapFailed
                            )))
                        }
                    } catch {
                        await send(.planningFailed(.network(error.localizedDescription)))
                    }
                }

            case .dismissPlanningError:
                state.planningError = nil
                return .none

            case .openAPIKeySheet:
                state.apiKeySheet = APIKeySheetFeature.State()
                return .none

            case .apiKeySheet(.presented(.delegate(.saved))):
                state.apiKeySheet = nil
                // If the prior failure was missing-key, retry automatically
                // so the user doesn't have to tap Try Again themselves.
                if case .missingAPIKey = state.planningError, let goalID = state.currentGoal?.id {
                    state.planningError = nil
                    return .send(.loadProgramForGoal(goalID))
                }
                return .none

            case .apiKeySheet(.presented(.delegate(.cancelled))):
                state.apiKeySheet = nil
                return .none

            case .apiKeySheet:
                return .none

            case .programLoaded(let program):
                state.currentProgram = program
                state.home.goal = state.currentGoal
                state.home.program = program
                return .send(.home(.onAppear(programID: program.id)))

            case .programLoadFailed(let message):
                state.home.loadFailure = message
                return .none

            case .programCreated:
                // Observer-driven hook; covered by `loadProgramForGoal`
                // for the current Goal Intake → Home flow. Future
                // engine-originated writes will exercise this directly.
                return .none

            case .sessionsChanged(let programID):
                guard state.currentProgram?.id == programID else { return .none }
                return .send(.home(.onAppear(programID: programID)))

            case .home(.delegate(.sessionTapped(let id))):
                state.destination = .sessionWorkspace(SessionWorkspaceFeature.State(sessionID: id))
                return .none

            case .home(.delegate(.resetTapped)):
                return .send(.resetTapped)

            case .home:
                return .none

            case .destination(.presented(.sessionWorkspace(.delegate(.dismiss)))):
                state.destination = nil
                return .none

            case .destination:
                return .none

            case .resetTapped:
                guard let goalID = state.currentGoal?.id else { return .none }
                return .run { [repository] _ in
                    try await repository.deleteGoal(id: goalID)
                    // Observer dispatches `.goalReset`.
                }

            case .goalReset:
                state.currentGoal = nil
                state.currentProgram = nil
                state.home = HomeFeature.State()
                state.destination = nil
                state.goalIntake = GoalIntakeFeature.State()
                if let profile = state.profile {
                    state.goalIntake.startingLevel = profile.startingLevel
                    state.goalIntake.weeklyTimeBudgetHours = profile.weeklyTimeBudgetHours
                    state.goalIntake.learningStyles = profile.learningStyles
                    state.goalIntake.targetOutcome = profile.targetOutcome ?? ""
                }
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$apiKeySheet, action: \.apiKeySheet) {
            APIKeySheetFeature()
        }
    }

}

extension AppFeature.Destination.State: Equatable {}
