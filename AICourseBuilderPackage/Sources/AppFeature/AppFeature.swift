import ChatClients
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import LearningModels
import LearningRepository
import LearningUI
import PlanningEngine

/// Top-level coordinator for the App Structure v2 surfaces. Owns the
/// bootstrap path (ensure a `LearnerProfile` exists, fetch every
/// `LearningGoal`) and routes the user between Library, the New Course
/// modal, Course Home, and the pushed Session Workspace destination via
/// the `AppScope` enum.
@Reducer
public struct AppFeature {
    @Reducer
    public enum Destination {
        case sessionWorkspace(SessionWorkspaceFeature)
    }

    /// Top-level app surface in the App Structure v2 model: Library is
    /// the home screen, `.newCourse` is the Goal Intake flow, and
    /// `.course(_)` is "inside" a specific course. Replaces the
    /// implicit single-course gating that used to be `currentGoal != nil`.
    /// Named `AppScope` (not `Scope`) to avoid the collision with TCA's
    /// `Scope` reducer that's used inside `body`.
    public enum AppScope: Equatable, Sendable {
        case library
        case newCourse
        case course(LearningGoal.ID)
    }

    @ObservableState
    public struct State: Equatable {
        public var isBootstrapping: Bool = true
        public var profile: LearnerProfile?
        /// All goals the learner has created. Drives the Library grid.
        /// Populated by `bootstrapCompleted` and refreshed by
        /// `goalsRefreshed` after observer-driven mutations.
        public var goals: IdentifiedArrayOf<LearningGoal> = []
        /// The currently-entered course. `nil` outside `.course(_)` scope.
        /// Kept as a stored property (rather than computed from `scope` +
        /// `goals`) so existing in-course flows (Home, ProgramMap,
        /// SessionWorkspace, planning, retries) and tests can read it
        /// without churn — Phase 4 collapses this when CourseHome lands.
        public var currentGoal: LearningGoal?
        public var currentProgram: ProgramBlueprint?
        public var goalIntake: GoalIntakeFeature.State = .init()
        /// Course Home — the merged Map + Today screen. Active when
        /// `appScope == .course(_)`.
        public var courseHome: CourseHomeFeature.State = .init()
        /// Top-level app surface. Defaults to `.library` after bootstrap.
        /// Renamed to `appScope` (not `scope`) to avoid the collision with
        /// `Store.scope(state:action:)` — bare `store.scope` then
        /// ambiguates between the dynamic-member-lookup property and the
        /// store-scoping method.
        public var appScope: AppScope = .library
        @Presents public var destination: Destination.State?

        /// True while a `PlanningEngine` call is in flight (outline OR
        /// full). `AppView` swaps the root surface to
        /// `PlanningProgressView` for as long as this is set; the
        /// progress copy is driven by `pendingPlanningMode`.
        public var isPlanning: Bool = false
        /// Tracks which planning call is/was in flight so retries and
        /// progress copy land on the right mode. Reset between runs.
        public var pendingPlanningMode: PlanningMode = .full
        /// Last planning failure. `AppView` shows `PlanningErrorView`
        /// when non-nil; `.missingAPIKey` auto-opens the key sheet.
        public var planningError: PlanningEngineError?
        /// Set when the user taps "Preview Plan" so the bootstrap
        /// completion handler routes to outline generation instead of
        /// the full blueprint call. Cleared once routed.
        public var pendingOutlineForNewGoal: Bool = false
        /// Result of the most recent `generateOutline`. When non-nil,
        /// `AppView` renders `ProgramPreviewView`. Cleared on confirm
        /// (Start Learning) or refine (back to Goal Intake).
        public var outlineProposal: OutlineProposal?
        /// Goal text held across a "Refine Goal" reset so the user
        /// doesn't have to retype after the goal row is deleted.
        public var preservedGoalText: String?
        /// API-key entry sheet, presented from Goal Intake's gear icon
        /// or auto-presented after `.missingAPIKey`.
        @Presents public var apiKeySheet: APIKeySheetFeature.State?

        public init() {}
    }

    public enum Action {
        case onAppear
        case bootstrapCompleted(profile: LearnerProfile, goals: [LearningGoal])
        case bootstrapFailed(String)
        case goalIntake(GoalIntakeFeature.Action)
        case courseHome(CourseHomeFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        /// Library tile / resume strip tap — enter a specific course.
        case courseSelected(LearningGoal.ID)
        /// "+ New course" tile / Topbar button — present Goal Intake.
        case newCourseRequested
        /// User backed out of Goal Intake without submitting.
        case goalIntakeCancelled
        /// Library Topbar back / breadcrumb tap — leave the current
        /// course and return to the Library grid.
        case returnToLibrary
        /// Internal: refresh `state.goals` from the repository after a
        /// mutation. Triggered by `goalCreated` / `goalReset` observers.
        case goalsRefreshed([LearningGoal])
        /// Internal helper: routes after a `goalCreated` observer fire.
        /// Stays in the New Course modal when a preview is pending,
        /// otherwise auto-enters the course like Library taps do.
        case routeAfterGoalCreated(LearningGoal.ID)
        /// Fired by the app-level observer after `createGoal` commits.
        case goalCreated(LearningGoal.ID)
        /// Fired after `deleteGoal` commits — returns the user to Goal Intake.
        case goalReset
        /// Internal: install (idempotent) + load the program for the
        /// current goal, then transition the user to Home Dashboard.
        case loadProgramForGoal(LearningGoal.ID)
        /// Internal: kicks off the fast outline call. On success, routes
        /// the user to `ProgramPreviewView`.
        case loadOutlineForGoal(LearningGoal.ID)
        /// Outline generation finished — store the proposal so the
        /// preview surface renders.
        case outlineCompleted(OutlineProposal)
        /// User tapped "Start Learning" on the Preview screen — clear
        /// outline state and trigger full blueprint generation.
        case outlineConfirmed
        /// User tapped "Refine Goal" on the Preview screen — preserve
        /// the goal text and reset back to Goal Intake.
        case outlineRefined
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
        Scope(state: \.courseHome, action: \.courseHome) {
            CourseHomeFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.isBootstrapping else { return .none }
                return .run { [repository] send in
                    do {
                        let profile = try await repository.ensureCurrentProfile()
                        let goals = try await repository.fetchAllGoals()
                        await send(.bootstrapCompleted(profile: profile, goals: goals))
                    } catch {
                        await send(.bootstrapFailed(error.localizedDescription))
                    }
                }

            case .bootstrapCompleted(let profile, let goals):
                state.isBootstrapping = false
                state.profile = profile
                state.goals = IdentifiedArray(uniqueElements: goals)
                state.courseHome.profile = profile
                // Seed the form with profile defaults so opening Goal
                // Intake starts from where the user left off.
                state.goalIntake.startingLevel = profile.startingLevel
                state.goalIntake.weeklyTimeBudgetHours = profile.weeklyTimeBudgetHours
                state.goalIntake.learningStyles = profile.learningStyles
                state.goalIntake.targetOutcome = profile.targetOutcome ?? ""
                // Library is the new home screen. Pre-redesign single-
                // course auto-resume is intentionally gone — the user
                // picks a course from Library, even if there's only one.
                state.appScope = .library
                return .none

            case .bootstrapFailed:
                state.isBootstrapping = false
                return .none

            case .goalIntake(.delegate(.submitTapped)):
                guard let profileID = state.profile?.id else { return .none }
                state.pendingOutlineForNewGoal = false
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

            case .goalIntake(.delegate(.previewSubmitted)):
                guard let profileID = state.profile?.id else { return .none }
                state.pendingOutlineForNewGoal = true
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
                    // Observer dispatches `.goalCreated`; bootstrapCompleted
                    // honors `pendingOutlineForNewGoal` and routes to
                    // `loadOutlineForGoal` instead of `loadProgramForGoal`.
                }

            case .goalIntake(.delegate(.openAPIKeySheet)):
                return .send(.openAPIKeySheet)

            case .goalIntake:
                return .none

            case .goalCreated(let id):
                return .run { [repository] send in
                    let goals = try await repository.fetchAllGoals()
                    await send(.goalsRefreshed(goals))
                    await send(.routeAfterGoalCreated(id))
                }

            case .goalsRefreshed(let goals):
                state.goals = IdentifiedArray(uniqueElements: goals)
                return .none

            case .routeAfterGoalCreated(let id):
                if state.appScope == .newCourse {
                    // Stay in the modal. Point `currentGoal` at the new
                    // row so the outline call has a valid ID.
                    state.currentGoal = state.goals[id: id]
                    if state.pendingOutlineForNewGoal {
                        state.pendingOutlineForNewGoal = false
                        return .send(.loadOutlineForGoal(id))
                    }
                    // No preview pending → user tapped Start without
                    // previewing. Exit modal and run full planning.
                    return .send(.courseSelected(id))
                }
                return .send(.courseSelected(id))

            case .courseSelected(let id):
                guard let goal = state.goals[id: id] else { return .none }
                state.appScope = .course(id)
                state.currentGoal = goal
                state.courseHome.profile = state.profile
                state.courseHome.goal = goal
                if state.pendingOutlineForNewGoal {
                    state.pendingOutlineForNewGoal = false
                    return .send(.loadOutlineForGoal(id))
                }
                return .send(.loadProgramForGoal(id))

            case .newCourseRequested:
                state.appScope = .newCourse
                state.goalIntake = GoalIntakeFeature.State()
                if let profile = state.profile {
                    state.goalIntake.startingLevel = profile.startingLevel
                    state.goalIntake.weeklyTimeBudgetHours = profile.weeklyTimeBudgetHours
                    state.goalIntake.learningStyles = profile.learningStyles
                    state.goalIntake.targetOutcome = profile.targetOutcome ?? ""
                }
                return .none

            case .goalIntakeCancelled:
                state.appScope = .library
                return .none

            case .returnToLibrary:
                state.appScope = .library
                state.currentGoal = nil
                state.currentProgram = nil
                state.destination = nil
                state.courseHome = CourseHomeFeature.State()
                state.courseHome.profile = state.profile
                return .none

            case .loadProgramForGoal(let goalID):
                guard let profileID = state.profile?.id else { return .none }
                state.isPlanning = true
                state.pendingPlanningMode = .full
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

            case .loadOutlineForGoal(let goalID):
                guard let profileID = state.profile?.id else { return .none }
                state.isPlanning = true
                state.pendingPlanningMode = .outline
                state.planningError = nil
                return .run { [planningEngine] send in
                    do {
                        let proposal = try await planningEngine.generateOutline(goalID, profileID)
                        await send(.outlineCompleted(proposal))
                    } catch let error as PlanningEngineError {
                        await send(.planningFailed(error))
                    } catch is CancellationError {
                        await send(.planningFailed(.cancelled))
                    } catch {
                        await send(.planningFailed(.network(error.localizedDescription)))
                    }
                }

            case .outlineCompleted(let proposal):
                state.isPlanning = false
                state.planningError = nil
                state.outlineProposal = proposal
                return .none

            case .outlineConfirmed:
                guard let goalID = state.currentGoal?.id else { return .none }
                state.outlineProposal = nil
                // From inside the New Course modal, route through
                // `courseSelected` so the modal exits AND full planning
                // kicks off. From `.course` scope (legacy refinement
                // flow), just trigger loadProgramForGoal directly.
                if state.appScope == .newCourse {
                    return .send(.courseSelected(goalID))
                }
                return .send(.loadProgramForGoal(goalID))

            case .outlineRefined:
                state.outlineProposal = nil
                state.preservedGoalText = state.currentGoal?.text ?? state.goalIntake.goalText
                // Refining = go back to Goal Intake, not Library. Pin
                // the scope here so the subsequent goalReset (via
                // resetTapped) doesn't bounce the user to Library.
                state.appScope = .newCourse
                return .send(.resetTapped)

            case .planningStarted:
                state.isPlanning = true
                state.planningError = nil
                return .none

            case .planningCompleted(let program):
                state.isPlanning = false
                state.planningError = nil
                state.currentProgram = program
                // Defensive: if planning succeeded while we're still in
                // `.newCourse` (e.g. the user clicked Start before any
                // scope transition), promote scope to the new course so
                // the modal doesn't re-render under us.
                if case .newCourse = state.appScope, let goalID = state.currentGoal?.id {
                    state.appScope = .course(goalID)
                }
                state.courseHome.goal = state.currentGoal
                state.courseHome.program = program
                return .send(.courseHome(.onAppear(programID: program.id)))

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
                switch state.pendingPlanningMode {
                case .outline:
                    return .send(.loadOutlineForGoal(goalID))
                case .full:
                    return .send(.loadProgramForGoal(goalID))
                }

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
                    switch state.pendingPlanningMode {
                    case .outline:
                        return .send(.loadOutlineForGoal(goalID))
                    case .full:
                        return .send(.loadProgramForGoal(goalID))
                    }
                }
                return .none

            case .apiKeySheet(.presented(.delegate(.cancelled))):
                state.apiKeySheet = nil
                return .none

            case .apiKeySheet:
                return .none

            case .programLoaded(let program):
                state.currentProgram = program
                state.courseHome.goal = state.currentGoal
                state.courseHome.program = program
                return .send(.courseHome(.onAppear(programID: program.id)))

            case .programLoadFailed(let message):
                state.courseHome.loadFailure = message
                return .none

            case .programCreated:
                // Observer-driven hook; covered by `loadProgramForGoal`
                // for the current Goal Intake → Home flow. Future
                // engine-originated writes will exercise this directly.
                return .none

            case .sessionsChanged(let programID):
                guard state.currentProgram?.id == programID else { return .none }
                return .send(.courseHome(.onAppear(programID: programID)))

            case .courseHome(.delegate(.sessionTapped(let id))):
                state.destination = .sessionWorkspace(SessionWorkspaceFeature.State(sessionID: id))
                return .none

            case .courseHome(.delegate(.returnToLibraryRequested)):
                return .send(.returnToLibrary)

            case .courseHome:
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
                state.outlineProposal = nil
                state.pendingOutlineForNewGoal = false
                state.courseHome = CourseHomeFeature.State()
                state.destination = nil
                state.goalIntake = GoalIntakeFeature.State()
                if let profile = state.profile {
                    state.courseHome.profile = profile
                    state.goalIntake.startingLevel = profile.startingLevel
                    state.goalIntake.weeklyTimeBudgetHours = profile.weeklyTimeBudgetHours
                    state.goalIntake.learningStyles = profile.learningStyles
                    state.goalIntake.targetOutcome = profile.targetOutcome ?? ""
                }
                if let preserved = state.preservedGoalText {
                    state.goalIntake.goalText = preserved
                    state.preservedGoalText = nil
                }
                // Routine deletes return to Library. `outlineRefined`
                // pre-sets `scope = .newCourse` so the user lands back
                // in Goal Intake instead.
                if state.appScope != .newCourse {
                    state.appScope = .library
                }
                return .run { [repository] send in
                    let goals = try await repository.fetchAllGoals()
                    await send(.goalsRefreshed(goals))
                }
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$apiKeySheet, action: \.apiKeySheet) {
            APIKeySheetFeature()
        }
    }

}

extension AppFeature.Destination.State: Equatable {}
