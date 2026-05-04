import AppFeature
import ComposableArchitecture
import Dependencies
import Foundation
import LearningModels
import LearningRepository
import Testing

/// Reducer-level coverage for the multiple_choice attempt-capture path.
/// `optimistic Attempt` and `recordAttempt` both mint UUIDs + `Date()`s
/// internally, so these tests use a **non-exhaustive `TestStore`** for
/// the cases where state contains those values — exact equality on
/// `state.attempts` would fail. Specific fields (kind, inputJSON,
/// resultJSON) get asserted directly against the resulting state.
///
/// No-op cases (invalid index, wrong kind) stay exhaustive — state
/// genuinely doesn't change.
@MainActor
@Suite("SessionWorkspaceFeature multiple_choice")
struct SessionWorkspaceFeatureMultipleChoiceTests {

    @Test func selectingValidOptionPersistsAndUpdatesState() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await seedSessionWithMCBlock()
        }

        let store = TestStore(
            initialState: SessionWorkspaceFeature.State(sessionID: context.sessionID)
        ) {
            SessionWorkspaceFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)

        await store.send(.multipleChoiceSelected(blockID: context.blockID, index: 1))
        // Optimistic update lands synchronously; assert the in-memory
        // attempt has the right shape before the persistence reconciles.
        let optimistic = store.state.attempts[context.blockID]
        #expect(optimistic != nil)
        #expect(optimistic?.kind == BlockKind.multipleChoice)
        #expect(optimistic?.inputJSON.contains("\"selected_index\":1") == true)
        #expect(optimistic?.resultJSON?.contains("\"correct\":true") == true)

        await store.receive(\.attemptRecorded)
        let persisted = store.state.attempts[context.blockID]
        #expect(persisted?.inputJSON.contains("\"selected_index\":1") == true)
        #expect(persisted?.resultJSON?.contains("\"correct\":true") == true)

        // Verify it actually round-tripped to SQLite.
        let onDisk = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await LearningRepository().fetchLatestAttempt(forBlockID: context.blockID)
        }
        #expect(onDisk?.inputJSON.contains("\"selected_index\":1") == true)
    }

    @Test func selectingWrongOptionMarksIncorrect() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await seedSessionWithMCBlock()
        }

        let store = TestStore(
            initialState: SessionWorkspaceFeature.State(sessionID: context.sessionID)
        ) {
            SessionWorkspaceFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)

        await store.send(.multipleChoiceSelected(blockID: context.blockID, index: 0))
        let optimistic = store.state.attempts[context.blockID]
        #expect(optimistic?.resultJSON?.contains("\"correct\":false") == true)
        #expect(optimistic?.resultJSON?.contains("\"score\":0") == true)

        await store.receive(\.attemptRecorded)
    }

    @Test func selectingInvalidIndexIsNoOp() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await seedSessionWithMCBlock()
        }

        let store = TestStore(
            initialState: SessionWorkspaceFeature.State(sessionID: context.sessionID)
        ) {
            SessionWorkspaceFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)

        // Out-of-range index — reducer returns .none, state unchanged.
        await store.send(.multipleChoiceSelected(blockID: context.blockID, index: 99))
        #expect(store.state.attempts.isEmpty)
    }

    @Test func selectingOnNonMCBlockIsNoOp() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await seedSessionWithConceptBlock()
        }

        let store = TestStore(
            initialState: SessionWorkspaceFeature.State(sessionID: context.sessionID)
        ) {
            SessionWorkspaceFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)

        await store.send(.multipleChoiceSelected(blockID: context.blockID, index: 0))
        #expect(store.state.attempts.isEmpty)
    }

    @Test func onAppearHydratesExistingAttempts() async throws {
        let database = try makeTestDatabase()
        let context = try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let context = try await seedSessionWithMCBlock()
            _ = try await LearningRepository().recordAttempt(
                blockID: context.blockID,
                kind: BlockKind.multipleChoice,
                inputJSON: #"{"selected_index":1}"#,
                resultJSON: #"{"correct":true,"score":1.0}"#
            )
            return context
        }

        let store = TestStore(
            initialState: SessionWorkspaceFeature.State(sessionID: context.sessionID)
        ) {
            SessionWorkspaceFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.loaded)

        let hydrated = store.state.attempts[context.blockID]
        #expect(hydrated?.inputJSON == #"{"selected_index":1}"#)
        #expect(hydrated?.resultJSON == #"{"correct":true,"score":1.0}"#)
    }

    // MARK: - Seed helpers

    private struct SessionContext {
        let sessionID: Session.ID
        let blockID: SessionBlock.ID
    }

    /// Seeds the parent chain + a single MC block with options
    /// `["a", "b", "c"]` and `correct_index = 1`.
    private func seedSessionWithMCBlock() async throws -> SessionContext {
        let repo = LearningRepository()
        let profile = try await repo.ensureCurrentProfile()
        let goalID = try await repo.createGoal(profileID: profile.id, text: "test")
        let programID = try await repo.createProgram(goalID: goalID, summary: "p")
        let stageID = try await repo.createStage(programID: programID, title: "s", intent: "i")
        let sprintID = try await repo.createSprint(stageID: stageID, title: "sp", focus: "f")
        let sessionID = try await repo.createSession(sprintID: sprintID, title: "se", objective: "o")
        let blockID = UUID()
        try await repo.createSessionBlocks([
            SessionBlock(
                id: blockID,
                sessionID: sessionID,
                order: 1,
                kind: BlockKind.multipleChoice,
                schemaVersion: 1,
                payloadJSON: #"{"question":"q","options":["a","b","c"],"correct_index":1,"explanation":"why"}"#
            ),
        ])
        return SessionContext(sessionID: sessionID, blockID: blockID)
    }

    private func seedSessionWithConceptBlock() async throws -> SessionContext {
        let repo = LearningRepository()
        let profile = try await repo.ensureCurrentProfile()
        let goalID = try await repo.createGoal(profileID: profile.id, text: "test")
        let programID = try await repo.createProgram(goalID: goalID, summary: "p")
        let stageID = try await repo.createStage(programID: programID, title: "s", intent: "i")
        let sprintID = try await repo.createSprint(stageID: stageID, title: "sp", focus: "f")
        let sessionID = try await repo.createSession(sprintID: sprintID, title: "se", objective: "o")
        let blockID = UUID()
        try await repo.createSessionBlocks([
            SessionBlock(
                id: blockID,
                sessionID: sessionID,
                order: 1,
                kind: BlockKind.concept,
                schemaVersion: 1,
                payloadJSON: #"{"heading":"h","body":"b"}"#
            ),
        ])
        return SessionContext(sessionID: sessionID, blockID: blockID)
    }
}
