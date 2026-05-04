import Foundation
import LearningModels

/// Pure function that resolves a `SessionBlock` row to one of four
/// outcomes — successfully decoded payload, unknown kind, unsupported
/// schema version, or malformed JSON. Extracted from `BlockView` so the
/// dispatch logic is unit-testable without standing up SwiftUI hosting.
enum BlockDispatch {
    enum Outcome: Equatable {
        case renderable(ResolvedKind)
        case unknownKind
        case unsupportedVersion(payloadVersion: Int, supportedVersion: Int)
        case malformedPayload
    }

    enum ResolvedKind: Equatable {
        case title(BlockPayload.Title)
        case objective(BlockPayload.Objective)
        case concept(BlockPayload.Concept)
        case example(BlockPayload.Example)
        case codeExercise(BlockPayload.CodeExercise)
        case multipleChoice(BlockPayload.MultipleChoice)
        case shortAnswer(BlockPayload.ShortAnswer)
        case reflection(BlockPayload.Reflection)
        case checkpoint(BlockPayload.Checkpoint)
        case reviewCard(BlockPayload.ReviewCard)
    }

    static func resolve(_ block: SessionBlock) -> Outcome {
        switch block.kind {
        case BlockKind.title:
            return decode(block, as: BlockPayload.Title.self,
                          version: BlockPayload.Title.currentSchemaVersion,
                          map: ResolvedKind.title)
        case BlockKind.objective:
            return decode(block, as: BlockPayload.Objective.self,
                          version: BlockPayload.Objective.currentSchemaVersion,
                          map: ResolvedKind.objective)
        case BlockKind.concept:
            return decode(block, as: BlockPayload.Concept.self,
                          version: BlockPayload.Concept.currentSchemaVersion,
                          map: ResolvedKind.concept)
        case BlockKind.example:
            return decode(block, as: BlockPayload.Example.self,
                          version: BlockPayload.Example.currentSchemaVersion,
                          map: ResolvedKind.example)
        case BlockKind.codeExercise:
            return decode(block, as: BlockPayload.CodeExercise.self,
                          version: BlockPayload.CodeExercise.currentSchemaVersion,
                          map: ResolvedKind.codeExercise)
        case BlockKind.multipleChoice:
            return decode(block, as: BlockPayload.MultipleChoice.self,
                          version: BlockPayload.MultipleChoice.currentSchemaVersion,
                          map: ResolvedKind.multipleChoice)
        case BlockKind.shortAnswer:
            return decode(block, as: BlockPayload.ShortAnswer.self,
                          version: BlockPayload.ShortAnswer.currentSchemaVersion,
                          map: ResolvedKind.shortAnswer)
        case BlockKind.reflection:
            return decode(block, as: BlockPayload.Reflection.self,
                          version: BlockPayload.Reflection.currentSchemaVersion,
                          map: ResolvedKind.reflection)
        case BlockKind.checkpoint:
            return decode(block, as: BlockPayload.Checkpoint.self,
                          version: BlockPayload.Checkpoint.currentSchemaVersion,
                          map: ResolvedKind.checkpoint)
        case BlockKind.reviewCard:
            return decode(block, as: BlockPayload.ReviewCard.self,
                          version: BlockPayload.ReviewCard.currentSchemaVersion,
                          map: ResolvedKind.reviewCard)
        default:
            return .unknownKind
        }
    }

    private static func decode<P: Decodable>(
        _ block: SessionBlock,
        as type: P.Type,
        version supportedVersion: Int,
        map: (P) -> ResolvedKind
    ) -> Outcome {
        if block.schemaVersion > supportedVersion {
            return .unsupportedVersion(
                payloadVersion: block.schemaVersion,
                supportedVersion: supportedVersion
            )
        }
        guard let data = block.payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(P.self, from: data) else {
            return .malformedPayload
        }
        return .renderable(map(payload))
    }
}
