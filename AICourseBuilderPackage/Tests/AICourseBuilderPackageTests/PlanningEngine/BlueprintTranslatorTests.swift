import Dependencies
import Foundation
import LearningModels
import LearningRepository
@testable import PlanningEngine
import Testing

/// End-to-end translator coverage. Each test bootstraps an in-memory
/// SQLite via `makeTestDatabase()`, seeds the parent profile + goal,
/// hands a `BlueprintProposal` to the translator, then walks the
/// resulting tables to assert ordering + status.
@MainActor
@Suite("BlueprintTranslator")
struct BlueprintTranslatorTests {

    @Test func translatePersistsProgramAndStages() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            let programID = try await BlueprintTranslator.translate(
                fivStageProposal(),
                goalID: goalID,
                repository: repo
            )

            let program = try await repo.fetchProgram(forGoalID: goalID)
            #expect(program?.id == programID)
            #expect(program?.summary == "Learn Haskell.")
            #expect(program?.durationWeeks == 12)

            let stages = try await repo.fetchStages(forProgramID: programID)
            #expect(stages.count == 5)
            #expect(stages.first?.status == Stage.Status.inProgress)
            for stage in stages.dropFirst() {
                #expect(stage.status == Stage.Status.locked)
            }
            #expect(stages.map(\.order) == [1, 2, 3, 4, 5])
        }
    }

    @Test func translatePersistsFirstStageSprintsOnly() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            let programID = try await BlueprintTranslator.translate(
                fivStageProposal(),
                goalID: goalID,
                repository: repo
            )

            let stages = try await repo.fetchStages(forProgramID: programID)
            let stage1 = try #require(stages.first)
            let stage1Sprints = try await repo.fetchSprints(forStageID: stage1.id)
            #expect(stage1Sprints.count == 2)
            #expect(stage1Sprints.first?.status == Sprint.Status.inProgress)
            #expect(stage1Sprints.last?.status == Sprint.Status.upcoming)

            // Every other stage has zero sprints.
            for stage in stages.dropFirst() {
                let sprints = try await repo.fetchSprints(forStageID: stage.id)
                #expect(sprints.isEmpty, "Stage 2+ should have no sprints yet")
            }
        }
    }

    @Test func translatePersistsAllBlocksInOrder() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            let programID = try await BlueprintTranslator.translate(
                fivStageProposal(),
                goalID: goalID,
                repository: repo
            )

            let sessions = try await repo.fetchSessions(forProgramID: programID)
            let session1 = try #require(sessions.first)
            let blocks = try await repo.fetchBlocks(forSessionID: session1.id)
            #expect(blocks.count == 10)
            #expect(blocks.map(\.order) == Array(1...10))
            #expect(blocks.first?.kind == BlockKind.title)
            #expect(blocks.last?.kind == BlockKind.reviewCard)
            #expect(blocks.allSatisfy { $0.schemaVersion == 1 })
        }
    }

    @Test func translateSurvivesUnsortedInput() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            var proposal = fivStageProposal()
            proposal.stages.reverse()
            proposal.firstStageSprints.reverse()
            proposal.firstSprintSessions.reverse()
            proposal.firstSessionBlocks.reverse()

            let programID = try await BlueprintTranslator.translate(
                proposal,
                goalID: goalID,
                repository: repo
            )
            let stages = try await repo.fetchStages(forProgramID: programID)
            // Translator sorts stages by order ascending before persisting.
            #expect(stages.map(\.order) == [1, 2, 3, 4, 5])
            #expect(stages.first?.status == Stage.Status.inProgress)
        }
    }

    private func fivStageProposal() -> BlueprintProposal {
        BlueprintProposal(
            program: .init(summary: "Learn Haskell.", durationWeeks: 12),
            stages: (1...5).map { BlueprintProposal.Stage(order: $0, title: "Stage \($0)", intent: "i") },
            firstStageSprints: [
                BlueprintProposal.Sprint(order: 1, title: "Sprint 1", focus: "f1"),
                BlueprintProposal.Sprint(order: 2, title: "Sprint 2", focus: "f2"),
            ],
            firstSprintSessions: [
                BlueprintProposal.Session(order: 1, title: "S1", objective: "o", estimatedMinutes: 15)
            ],
            firstSessionBlocks: tenCanonicalBlocks()
        )
    }

    private func tenCanonicalBlocks() -> [BlueprintProposal.Block] {
        [
            blk(1, BlockKind.title, ["text": .string("L1")]),
            blk(2, BlockKind.objective, ["statement": .string("learn")]),
            blk(3, BlockKind.concept, ["heading": .string("h"), "body": .string("b")]),
            blk(4, BlockKind.example, ["prose": .string("hello")]),
            blk(5, BlockKind.codeExercise, ["prompt": .string("p"), "language": .string("haskell")]),
            blk(6, BlockKind.multipleChoice, [
                "question": .string("q?"),
                "options": .array([.string("a"), .string("b")]),
                "correct_index": .int(1),
            ]),
            blk(7, BlockKind.shortAnswer, ["question": .string("q"), "expected_answer": .string("a")]),
            blk(8, BlockKind.reflection, ["prompt": .string("r")]),
            blk(9, BlockKind.checkpoint, ["prompt": .string("p")]),
            blk(10, BlockKind.reviewCard, [
                "concept_id": .string(UUID().uuidString),
                "front": .string("f"),
                "back": .string("b"),
            ]),
        ]
    }

    private func blk(_ order: Int, _ kind: String, _ fields: [String: JSONValue]) -> BlueprintProposal.Block {
        BlueprintProposal.Block(order: order, kind: kind, schemaVersion: 1, payload: .object(fields))
    }
}
