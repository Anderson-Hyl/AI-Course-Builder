import ComposableArchitecture
import Foundation
import LearningModels
import LearningRepository

/// Top-level coordinator. Owns the bootstrap path (ensure a `LearnerProfile`
/// exists, fetch any active `LearningGoal`) and the root navigation
/// state. Currently routes between Goal Intake and a placeholder Home
/// stub; will grow to host Home Dashboard / Session Workspace / Program
/// Map / Review Vault as those screens land.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        /// Until bootstrap completes we render a `ProgressView` so the UI
        /// doesn't briefly flash Goal Intake before recognizing a
        /// persisted goal exists.
        public var isBootstrapping: Bool = true
        /// Current device-local profile. Set during bootstrap.
        public var profile: LearnerProfile?
        /// Active goal (if any). When nil, the user sees Goal Intake.
        /// When set, the user sees the placeholder Home stub.
        public var currentGoal: LearningGoal?
        /// Form state for the Goal Intake screen. Always present so a
        /// reset preserves field defaults; the view only displays it
        /// when `currentGoal == nil`.
        public var goalIntake: GoalIntakeFeature.State = .init()

        public init() {}
    }

    public enum Action {
        case onAppear
        case bootstrapCompleted(profile: LearnerProfile, goal: LearningGoal?)
        case bootstrapFailed(String)
        case goalIntake(GoalIntakeFeature.Action)
        /// Fired by the app-level `LearningMutationObserver` after
        /// `LearningRepository.createGoal` commits. Reducer reloads the
        /// goal row so the placeholder Home stub has the persisted text.
        case goalCreated(LearningGoal.ID)
        /// Fired by the app-level observer after `deleteGoal` commits.
        /// Returns the user to Goal Intake.
        case goalReset
        /// User tapped Reset on the placeholder Home stub.
        case resetTapped
    }

    public init() {}

    @Dependency(\.learningRepository) var repository

    public var body: some ReducerOf<Self> {
        Scope(state: \.goalIntake, action: \.goalIntake) {
            GoalIntakeFeature()
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
                // Seed the form with profile defaults so re-opening Goal
                // Intake (after a Reset) starts from where the user left
                // off rather than full defaults.
                state.goalIntake.startingLevel = profile.startingLevel
                state.goalIntake.weeklyTimeBudgetHours = profile.weeklyTimeBudgetHours
                state.goalIntake.learningStyles = profile.learningStyles
                state.goalIntake.targetOutcome = profile.targetOutcome ?? ""
                return .none

            case .bootstrapFailed:
                // Surface bootstrap failures by leaving `isBootstrapping`
                // true and letting the UI render an inline error. We
                // don't have a toast surface yet — log + render-state
                // gating is enough for a v1 bootstrap.
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
                    // Observer dispatches `.goalCreated` once the write
                    // commits — nothing more to do from this effect.
                }

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

            case .resetTapped:
                guard let goalID = state.currentGoal?.id else { return .none }
                return .run { [repository] _ in
                    try await repository.deleteGoal(id: goalID)
                    // Observer dispatches `.goalReset`.
                }

            case .goalReset:
                state.currentGoal = nil
                state.goalIntake = GoalIntakeFeature.State()
                if let profile = state.profile {
                    // Re-seed defaults from the persisted profile so
                    // the form remembers the user's last chosen settings
                    // even though the goal text resets to empty.
                    state.goalIntake.startingLevel = profile.startingLevel
                    state.goalIntake.weeklyTimeBudgetHours = profile.weeklyTimeBudgetHours
                    state.goalIntake.learningStyles = profile.learningStyles
                    state.goalIntake.targetOutcome = profile.targetOutcome ?? ""
                }
                return .none
            }
        }
    }

}

// MARK: - Repository dependency

extension DependencyValues {
    /// `LearningRepository` injected through Dependencies so reducers
    /// reach it without parameter threading and tests can swap in
    /// fixtures via `withDependencies`.
    public var learningRepository: LearningRepository {
        get { self[LearningRepositoryKey.self] }
        set { self[LearningRepositoryKey.self] = newValue }
    }
}

private enum LearningRepositoryKey: DependencyKey {
    static let liveValue = LearningRepository()
    static let testValue = LearningRepository()
}
