import Foundation
import LearningModels

/// Stops a malformed `BlueprintProposal` from reaching the database.
/// Catches all the failures the JSON Schema can't reliably enforce
/// (cross-field invariants, payload-shape-by-kind, schema version) so the
/// engine can surface a retryable error rather than persisting a half-
/// broken session.
enum BlueprintProposalValidator {
    static func validate(_ proposal: BlueprintProposal) throws {
        guard (4...8).contains(proposal.stages.count) else {
            throw PlanningEngineError.proposalValidationFailed(
                reason: "Stage count \(proposal.stages.count) out of [4...8]."
            )
        }
        guard (1...8).contains(proposal.firstStageSprints.count) else {
            throw PlanningEngineError.proposalValidationFailed(
                reason: "First-stage sprints \(proposal.firstStageSprints.count) out of [1...8]."
            )
        }
        guard (1...6).contains(proposal.firstSprintSessions.count) else {
            throw PlanningEngineError.proposalValidationFailed(
                reason: "First-sprint sessions \(proposal.firstSprintSessions.count) out of [1...6]."
            )
        }
        guard (8...12).contains(proposal.firstSessionBlocks.count) else {
            throw PlanningEngineError.proposalValidationFailed(
                reason: "First-session blocks \(proposal.firstSessionBlocks.count) out of [8...12]."
            )
        }

        let known = Set(BlockKind.all)
        for block in proposal.firstSessionBlocks {
            guard known.contains(block.kind) else {
                throw PlanningEngineError.proposalValidationFailed(
                    reason: "Unknown block kind '\(block.kind)'."
                )
            }
            guard block.schemaVersion == 1 else {
                throw PlanningEngineError.proposalValidationFailed(
                    reason: "Block kind '\(block.kind)' has schema_version \(block.schemaVersion); expected 1."
                )
            }
            try validatePayloadShape(kind: block.kind, payload: block.payload)
        }
    }

    private static func validatePayloadShape(kind: String, payload: JSONValue) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(payload)
        } catch {
            throw PlanningEngineError.proposalValidationFailed(
                reason: "Block kind '\(kind)' payload could not be re-encoded: \(error.localizedDescription)"
            )
        }

        let decoder = JSONDecoder()
        do {
            switch kind {
            case BlockKind.title:
                _ = try decoder.decode(BlockPayload.Title.self, from: data)
            case BlockKind.objective:
                _ = try decoder.decode(BlockPayload.Objective.self, from: data)
            case BlockKind.concept:
                _ = try decoder.decode(BlockPayload.Concept.self, from: data)
            case BlockKind.example:
                let example = try decoder.decode(BlockPayload.Example.self, from: data)
                let prose = (example.prose ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let code = (example.code ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if prose.isEmpty, code.isEmpty {
                    throw PlanningEngineError.proposalValidationFailed(
                        reason: "Example block must have non-empty prose or code."
                    )
                }
            case BlockKind.codeExercise:
                _ = try decoder.decode(BlockPayload.CodeExercise.self, from: data)
            case BlockKind.multipleChoice:
                let mc = try decoder.decode(BlockPayload.MultipleChoice.self, from: data)
                guard mc.options.indices.contains(mc.correctIndex) else {
                    throw PlanningEngineError.proposalValidationFailed(
                        reason: "multiple_choice correct_index \(mc.correctIndex) out of options range \(mc.options.count)."
                    )
                }
            case BlockKind.shortAnswer:
                _ = try decoder.decode(BlockPayload.ShortAnswer.self, from: data)
            case BlockKind.reflection:
                _ = try decoder.decode(BlockPayload.Reflection.self, from: data)
            case BlockKind.checkpoint:
                _ = try decoder.decode(BlockPayload.Checkpoint.self, from: data)
            case BlockKind.reviewCard:
                _ = try decoder.decode(BlockPayload.ReviewCard.self, from: data)
            default:
                throw PlanningEngineError.proposalValidationFailed(
                    reason: "Unknown block kind '\(kind)'."
                )
            }
        } catch let error as PlanningEngineError {
            throw error
        } catch {
            throw PlanningEngineError.proposalValidationFailed(
                reason: "Block kind '\(kind)' payload failed to decode: \(error.localizedDescription)"
            )
        }
    }
}
