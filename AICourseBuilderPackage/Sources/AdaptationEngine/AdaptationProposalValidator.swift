import Foundation

/// Stops a malformed `AdaptationProposal` from reaching the database.
/// Catches the cross-field invariants the JSON Schema can't enforce
/// (closed enums on string fields, range checks, "review item refers
/// to a concept the proposal didn't list") so the engine can surface
/// a retryable error rather than persisting partial state.
enum AdaptationProposalValidator {
    /// Allowed `due_in_days` values for `ReviewItem`. Constrained to
    /// the SM-2 ladder rungs the planner is supposed to pick from
    /// rather than letting the LLM emit arbitrary integers — keeps the
    /// review queue's UX predictable across prompts.
    static let allowedReviewIntervalsDays: Set<Int> = [1, 2, 3, 7, 14, 30]

    static func validate(_ proposal: AdaptationProposal) throws {
        let allowedCompletions = Set(AdaptationProposal.Outcome.Completion.all)
        guard allowedCompletions.contains(proposal.outcome.completion) else {
            throw AdaptationEngineError.proposalValidationFailed(
                reason: "Unknown completion '\(proposal.outcome.completion)'."
            )
        }
        guard !proposal.outcome.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AdaptationEngineError.proposalValidationFailed(
                reason: "Outcome summary is empty."
            )
        }

        let allowedNextSteps = Set(AdaptationProposal.NextStep.Kind.all)
        guard allowedNextSteps.contains(proposal.nextStep.kind) else {
            throw AdaptationEngineError.proposalValidationFailed(
                reason: "Unknown next_step.kind '\(proposal.nextStep.kind)'."
            )
        }

        for concept in proposal.concepts {
            guard !concept.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AdaptationEngineError.proposalValidationFailed(
                    reason: "Concept title is empty."
                )
            }
            guard (0.0...1.0).contains(concept.masteryEstimate) else {
                throw AdaptationEngineError.proposalValidationFailed(
                    reason: "Concept '\(concept.title)' mastery_estimate \(concept.masteryEstimate) out of [0, 1]."
                )
            }
            guard (0.0...1.0).contains(concept.confidence) else {
                throw AdaptationEngineError.proposalValidationFailed(
                    reason: "Concept '\(concept.title)' confidence \(concept.confidence) out of [0, 1]."
                )
            }
        }

        let conceptTitles = Set(proposal.concepts.map { $0.title.lowercased() })
        for item in proposal.reviewItems {
            guard allowedReviewIntervalsDays.contains(item.dueInDays) else {
                throw AdaptationEngineError.proposalValidationFailed(
                    reason: "Review item due_in_days \(item.dueInDays) not in allowed set \(allowedReviewIntervalsDays.sorted())."
                )
            }
            guard !item.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !item.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw AdaptationEngineError.proposalValidationFailed(
                    reason: "Review item for concept '\(item.conceptTitle)' has empty front or back."
                )
            }
            guard conceptTitles.contains(item.conceptTitle.lowercased()) else {
                throw AdaptationEngineError.proposalValidationFailed(
                    reason: "Review item references concept '\(item.conceptTitle)' that's not in the concepts list."
                )
            }
        }
    }
}
