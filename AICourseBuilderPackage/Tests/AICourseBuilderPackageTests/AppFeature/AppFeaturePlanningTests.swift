import AppFeature
import ChatClients
import ComposableArchitecture
import Dependencies
import Foundation
import LearningModels
import LearningRepository
import PlanningEngine
import Testing

/// `AppFeature` reducer-level coverage for the planning flow. Uses
/// non-exhaustive `TestStore` (`exhaustivity = .off`) because cross-
/// feature transitions cascade through multiple async effects;
/// matching `SessionWorkspaceFeatureTests`' discipline.
@MainActor
@Suite("AppFeature planning flow")
struct AppFeaturePlanningTests {

    @Test func planningHappyPathSetsCurrentProgram() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await seedProfileAndGoal()
        }

        var initialState = AppFeature.State()
        initialState.profile = context.profile
        initialState.currentGoal = context.goal
        initialState.isBootstrapping = false

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.planningEngine = PlanningEngine(
                generateBlueprint: { goalID, _, _ in
                    let repo = LearningRepository()
                    return try await repo.installDemoProgram(goalID: goalID)
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.loadProgramForGoal(context.goalID))
        await store.receive(\.planningCompleted)

        #expect(store.state.isPlanning == false)
        #expect(store.state.planningError == nil)
        #expect(store.state.currentProgram != nil)
    }

    @Test func planningMissingKeyAutoOpensSheet() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await seedProfileAndGoal()
        }

        var initialState = AppFeature.State()
        initialState.profile = context.profile
        initialState.currentGoal = context.goal
        initialState.isBootstrapping = false

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.planningEngine = PlanningEngine(
                generateBlueprint: { _, _, _ in
                    throw PlanningEngineError.missingAPIKey
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.loadProgramForGoal(context.goalID))
        await store.receive(\.planningFailed)

        #expect(store.state.planningError == .missingAPIKey)
        #expect(store.state.apiKeySheet != nil)
    }

    @Test func gearTapInGoalIntakeOpensSheet() async throws {
        let database = try makeTestDatabase()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.goalIntake(.gearTapped))

        // The full chain: gearTapped → goalIntake.delegate.openAPIKeySheet
        // → AppFeature.openAPIKeySheet → apiKeySheet set. With
        // exhaustivity = .off, we just await the final state.
        await store.skipReceivedActions()
        #expect(store.state.apiKeySheet != nil)
    }

    @Test func planningFailureKeepsCurrentGoalSoRetryWorks() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await seedProfileAndGoal()
        }

        var initialState = AppFeature.State()
        initialState.profile = context.profile
        initialState.currentGoal = context.goal
        initialState.isBootstrapping = false

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.planningEngine = PlanningEngine(
                generateBlueprint: { _, _, _ in
                    throw PlanningEngineError.modelDidNotCallTool(stopReason: "end_turn")
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.loadProgramForGoal(context.goalID))
        await store.receive(\.planningFailed)

        #expect(store.state.currentGoal?.id == context.goalID)
        #expect(store.state.planningError == .modelDidNotCallTool(stopReason: "end_turn"))
    }

    // MARK: - Seed

    private struct GoalContext {
        let profile: LearnerProfile
        let goal: LearningGoal
        var goalID: LearningGoal.ID { goal.id }
    }

    private func seedProfileAndGoal() async throws -> GoalContext {
        let repo = LearningRepository()
        let profile = try await repo.ensureCurrentProfile()
        let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")
        let goals = try await repo.fetchAllGoals()
        let goal = try #require(goals.first(where: { $0.id == goalID }))
        return GoalContext(profile: profile, goal: goal)
    }
}
