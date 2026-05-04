import Dependencies
import Foundation
import LearningModels
import LearningRepository
import Testing

/// Repository round-trip coverage for the new attempt-capture seam.
/// Each test bootstraps a fresh in-memory SQLite via `makeTestDatabase()`
/// + injects it through `withDependencies`. Parent rows (profile → goal →
/// program → stage → sprint → session → blocks) are seeded via the
/// existing `LearningRepository` mutators so FK + cascade behavior is
/// exercised the same way production callers exercise it.
@MainActor
@Suite("LearningRepository attempts")
struct AttemptRepositoryTests {

    @Test func recordAttemptReturnsIDAndPersistsRow() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let blockID = try await seedSingleMCBlock(repo: repo)

            let id = try await repo.recordAttempt(
                blockID: blockID,
                kind: BlockKind.multipleChoice,
                inputJSON: #"{"selected_index":2}"#,
                resultJSON: #"{"correct":true,"score":1.0}"#
            )

            let saved = try await repo.fetchLatestAttempt(forBlockID: blockID)
            #expect(saved?.id == id)
            #expect(saved?.blockID == blockID)
            #expect(saved?.kind == BlockKind.multipleChoice)
            #expect(saved?.inputJSON == #"{"selected_index":2}"#)
            #expect(saved?.resultJSON == #"{"correct":true,"score":1.0}"#)
            #expect(saved?.scoredAt != nil, "scoredAt should be set when resultJSON is non-nil")
        }
    }

    @Test func fetchLatestAttemptReturnsNilWhenNoneRecorded() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let blockID = try await seedSingleMCBlock(repo: repo)

            let saved = try await repo.fetchLatestAttempt(forBlockID: blockID)
            #expect(saved == nil)
        }
    }

    @Test func recordAttemptLeavesScoredAtNilWhenResultMissing() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let blockID = try await seedSingleMCBlock(repo: repo)

            _ = try await repo.recordAttempt(
                blockID: blockID,
                kind: BlockKind.shortAnswer,
                inputJSON: #"{"text":"placeholder"}"#,
                resultJSON: nil
            )

            let saved = try await repo.fetchLatestAttempt(forBlockID: blockID)
            #expect(saved?.scoredAt == nil)
            #expect(saved?.resultJSON == nil)
        }
    }

    @Test func fetchLatestAttemptsReturnsOneEntryPerBlock() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let context = try await seedSessionWithTwoBlocks(repo: repo)

            _ = try await repo.recordAttempt(
                blockID: context.blockA,
                kind: BlockKind.multipleChoice,
                inputJSON: #"{"selected_index":0}"#,
                resultJSON: #"{"correct":false,"score":0.0}"#
            )
            _ = try await repo.recordAttempt(
                blockID: context.blockB,
                kind: BlockKind.multipleChoice,
                inputJSON: #"{"selected_index":1}"#,
                resultJSON: #"{"correct":true,"score":1.0}"#
            )

            let map = try await repo.fetchLatestAttempts(forSessionID: context.sessionID)
            #expect(map.count == 2)
            #expect(map[context.blockA]?.inputJSON == #"{"selected_index":0}"#)
            #expect(map[context.blockB]?.inputJSON == #"{"selected_index":1}"#)
        }
    }

    @Test func fetchLatestAttemptsExcludesBlocksFromOtherSessions() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let primary = try await seedSessionWithTwoBlocks(repo: repo)
            let other = try await seedSingleMCBlock(repo: repo)

            _ = try await repo.recordAttempt(
                blockID: primary.blockA,
                kind: BlockKind.multipleChoice,
                inputJSON: #"{"selected_index":0}"#,
                resultJSON: #"{"correct":false,"score":0.0}"#
            )
            _ = try await repo.recordAttempt(
                blockID: other,
                kind: BlockKind.multipleChoice,
                inputJSON: #"{"selected_index":3}"#,
                resultJSON: #"{"correct":false,"score":0.0}"#
            )

            let map = try await repo.fetchLatestAttempts(forSessionID: primary.sessionID)
            #expect(map.count == 1)
            #expect(map[primary.blockA] != nil)
            #expect(map[other] == nil, "Should not surface attempts from a different session")
        }
    }

    // MARK: - Seed helpers

    private struct SessionContext {
        let sessionID: Session.ID
        let blockA: SessionBlock.ID
        let blockB: SessionBlock.ID
    }

    private func seedSingleMCBlock(repo: LearningRepository) async throws -> SessionBlock.ID {
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
                payloadJSON: #"{"question":"q","options":["a","b","c"],"correct_index":1}"#
            ),
        ])
        return blockID
    }

    private func seedSessionWithTwoBlocks(repo: LearningRepository) async throws -> SessionContext {
        let profile = try await repo.ensureCurrentProfile()
        let goalID = try await repo.createGoal(profileID: profile.id, text: "test")
        let programID = try await repo.createProgram(goalID: goalID, summary: "p")
        let stageID = try await repo.createStage(programID: programID, title: "s", intent: "i")
        let sprintID = try await repo.createSprint(stageID: stageID, title: "sp", focus: "f")
        let sessionID = try await repo.createSession(sprintID: sprintID, title: "se", objective: "o")
        let blockA = UUID()
        let blockB = UUID()
        try await repo.createSessionBlocks([
            SessionBlock(
                id: blockA,
                sessionID: sessionID,
                order: 1,
                kind: BlockKind.multipleChoice,
                schemaVersion: 1,
                payloadJSON: #"{"question":"qA","options":["a","b"],"correct_index":1}"#
            ),
            SessionBlock(
                id: blockB,
                sessionID: sessionID,
                order: 2,
                kind: BlockKind.multipleChoice,
                schemaVersion: 1,
                payloadJSON: #"{"question":"qB","options":["a","b"],"correct_index":1}"#
            ),
        ])
        return SessionContext(sessionID: sessionID, blockA: blockA, blockB: blockB)
    }
}
