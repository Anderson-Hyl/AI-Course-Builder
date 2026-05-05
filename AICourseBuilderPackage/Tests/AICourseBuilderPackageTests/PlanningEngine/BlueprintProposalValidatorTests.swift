import Foundation
import LearningModels
@testable import PlanningEngine
import Testing

@Suite("BlueprintProposalValidator")
struct BlueprintProposalValidatorTests {

    @Test func validateAcceptsCanonicalProposal() throws {
        let proposal = makeCanonicalProposal()
        try BlueprintProposalValidator.validate(proposal)
    }

    @Test func validateRejectsThreeStages() {
        var proposal = makeCanonicalProposal()
        proposal.stages = Array(proposal.stages.prefix(3))
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    @Test func validateRejectsNineStages() {
        var proposal = makeCanonicalProposal()
        proposal.stages = (1...9).map { BlueprintProposal.Stage(order: $0, title: "Stage \($0)", intent: "i") }
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    @Test func validateRejectsSchemaVersionTwo() {
        var proposal = makeCanonicalProposal()
        proposal.firstSessionBlocks[0].schemaVersion = 2
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    @Test func validateRejectsUnknownBlockKind() {
        var proposal = makeCanonicalProposal()
        proposal.firstSessionBlocks[0].kind = "video"
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    @Test func validateRejectsMultipleChoiceWithBadCorrectIndex() {
        var proposal = makeCanonicalProposal()
        proposal.firstSessionBlocks[5] = BlueprintProposal.Block(
            order: 6,
            kind: BlockKind.multipleChoice,
            schemaVersion: 1,
            payload: .object([
                "question": .string("q?"),
                "options": .array([.string("a"), .string("b")]),
                "correct_index": .int(5),
            ])
        )
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    @Test func validateRejectsConceptMissingHeading() {
        var proposal = makeCanonicalProposal()
        proposal.firstSessionBlocks[2] = BlueprintProposal.Block(
            order: 3,
            kind: BlockKind.concept,
            schemaVersion: 1,
            payload: .object(["body": .string("missing heading")])
        )
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    @Test func validateRejectsExampleWithEmptyProseAndCode() {
        var proposal = makeCanonicalProposal()
        proposal.firstSessionBlocks[3] = BlueprintProposal.Block(
            order: 4,
            kind: BlockKind.example,
            schemaVersion: 1,
            payload: .object([
                "heading": .string("Empty"),
                "prose": .string(""),
                "code": .string(""),
            ])
        )
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    @Test func validateRejectsTooFewBlocks() {
        var proposal = makeCanonicalProposal()
        proposal.firstSessionBlocks = Array(proposal.firstSessionBlocks.prefix(7))
        #expect(throws: PlanningEngineError.self) {
            try BlueprintProposalValidator.validate(proposal)
        }
    }

    // MARK: - Builder

    /// Builds a proposal with all 10 BlockKind values populated correctly
    /// — used as the happy-case base, then mutated per test to inject
    /// specific failure modes.
    private func makeCanonicalProposal() -> BlueprintProposal {
        BlueprintProposal(
            program: .init(summary: "Learn Haskell.", durationWeeks: 12),
            normalizedTopic: "haskell",
            stages: (1...5).map { BlueprintProposal.Stage(order: $0, title: "Stage \($0)", intent: "i\($0)") },
            firstStageSprints: [BlueprintProposal.Sprint(order: 1, title: "Sprint 1", focus: "f1")],
            firstSprintSessions: [
                BlueprintProposal.Session(order: 1, title: "S1", objective: "o", estimatedMinutes: 15)
            ],
            firstSessionBlocks: canonicalBlocks()
        )
    }

    private func canonicalBlocks() -> [BlueprintProposal.Block] {
        [
            block(order: 1, kind: BlockKind.title, payload: .object(["text": .string("L1")])),
            block(order: 2, kind: BlockKind.objective, payload: .object(["statement": .string("learn")])),
            block(order: 3, kind: BlockKind.concept, payload: .object([
                "heading": .string("h"),
                "body": .string("b"),
            ])),
            block(order: 4, kind: BlockKind.example, payload: .object([
                "heading": .string("e"),
                "prose": .string("hello"),
            ])),
            block(order: 5, kind: BlockKind.codeExercise, payload: .object([
                "prompt": .string("write greet"),
                "language": .string("haskell"),
            ])),
            block(order: 6, kind: BlockKind.multipleChoice, payload: .object([
                "question": .string("q?"),
                "options": .array([.string("a"), .string("b"), .string("c")]),
                "correct_index": .int(1),
            ])),
            block(order: 7, kind: BlockKind.shortAnswer, payload: .object([
                "question": .string("define"),
                "expected_answer": .string("answer"),
            ])),
            block(order: 8, kind: BlockKind.reflection, payload: .object([
                "prompt": .string("reflect"),
            ])),
            block(order: 9, kind: BlockKind.checkpoint, payload: .object([
                "prompt": .string("how confident"),
                "scale_min": .int(1),
                "scale_max": .int(5),
            ])),
            block(order: 10, kind: BlockKind.reviewCard, payload: .object([
                "concept_id": .string(UUID().uuidString),
                "front": .string("f"),
                "back": .string("b"),
            ])),
        ]
    }

    private func block(order: Int, kind: String, payload: JSONValue) -> BlueprintProposal.Block {
        BlueprintProposal.Block(order: order, kind: kind, schemaVersion: 1, payload: payload)
    }
}
