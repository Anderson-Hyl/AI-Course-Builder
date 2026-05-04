import Foundation
import LearningModels
@testable import LessonRendering
import Testing

/// Tests `BlockDispatch.resolve(_:)` — the central dispatcher that maps
/// a `SessionBlock` row to a renderable outcome. Pure logic, no
/// SwiftUI hosting required.
@Suite("BlockView dispatch")
struct BlockViewDispatchTests {

    @Test func unknownKindResolvesToUnknownKind() {
        #expect(BlockDispatch.resolve(Fixtures.unknownKindBlock) == .unknownKind)
    }

    @Test func futureSchemaVersionResolvesToUnsupportedVersion() {
        let outcome = BlockDispatch.resolve(Fixtures.unsupportedVersionTitle)
        #expect(outcome == .unsupportedVersion(payloadVersion: 99, supportedVersion: 1))
    }

    @Test func malformedJSONResolvesToMalformedPayload() {
        #expect(BlockDispatch.resolve(Fixtures.malformedConcept) == .malformedPayload)
    }

    @Test func everyHaskellBlockResolvesRenderable() {
        for block in Fixtures.haskellSessionBlocks {
            let outcome = BlockDispatch.resolve(block)
            switch outcome {
            case .renderable: continue
            case .unknownKind, .unsupportedVersion, .malformedPayload:
                Issue.record("Expected .renderable for kind \(block.kind), got \(outcome)")
            }
        }
    }

    @Test func everyMathBlockResolvesRenderable() {
        for block in Fixtures.mathSessionBlocks {
            let outcome = BlockDispatch.resolve(block)
            switch outcome {
            case .renderable: continue
            case .unknownKind, .unsupportedVersion, .malformedPayload:
                Issue.record("Expected .renderable for kind \(block.kind), got \(outcome)")
            }
        }
    }

    @Test func everyChemistryBlockResolvesRenderable() {
        for block in Fixtures.chemistrySessionBlocks {
            let outcome = BlockDispatch.resolve(block)
            switch outcome {
            case .renderable: continue
            case .unknownKind, .unsupportedVersion, .malformedPayload:
                Issue.record("Expected .renderable for kind \(block.kind), got \(outcome)")
            }
        }
    }

    @Test func haskellBlocksProduceMatchingResolvedKinds() {
        let kinds = Fixtures.haskellSessionBlocks.map { block -> String in
            switch BlockDispatch.resolve(block) {
            case .renderable(let resolved): return resolvedKindName(resolved)
            default: return "<not-renderable>"
            }
        }
        #expect(kinds == [
            "title", "objective", "concept", "example", "code_exercise",
            "multiple_choice", "short_answer", "reflection", "checkpoint", "review_card",
        ])
    }

    private func resolvedKindName(_ kind: BlockDispatch.ResolvedKind) -> String {
        switch kind {
        case .title: return BlockKind.title
        case .objective: return BlockKind.objective
        case .concept: return BlockKind.concept
        case .example: return BlockKind.example
        case .codeExercise: return BlockKind.codeExercise
        case .multipleChoice: return BlockKind.multipleChoice
        case .shortAnswer: return BlockKind.shortAnswer
        case .reflection: return BlockKind.reflection
        case .checkpoint: return BlockKind.checkpoint
        case .reviewCard: return BlockKind.reviewCard
        }
    }
}
