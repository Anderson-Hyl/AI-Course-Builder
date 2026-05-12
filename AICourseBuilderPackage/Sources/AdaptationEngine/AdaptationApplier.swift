import Foundation
import LearningModels
import LearningRepository

/// Turns a validated `AdaptationProposal` into the repository's write
/// sequence. Order matters because `MasteryState` upserts and
/// `ReviewItem` inserts both target `ConceptNode.id`s — we have to
/// resolve concepts first, then upsert mastery, then schedule reviews.
///
/// Cascade rules:
/// - Always marks the session `completed`.
/// - If the session was the last `notStarted`/`inProgress` session in
///   its sprint, also marks the sprint `completed`.
/// - If the sprint was the last non-`completed` sprint in its stage,
///   also marks the stage `completed`.
/// - Persists the full proposal as an `Artifact` of kind
///   `session_adaptation` so Review Vault can replay it later.
enum AdaptationApplier {
    /// Apply the validated proposal. Returns the digest the engine
    /// surfaces back to the workspace as `AdaptationSummary`.
    static func apply(
        _ proposal: AdaptationProposal,
        sessionID: Session.ID,
        repository: LearningRepository
    ) async throws -> AdaptationSummary {
        do {
            guard let session = try await repository.fetchSession(id: sessionID),
                  let sprint = try await repository.fetchSprint(id: session.sprintID),
                  let stage = try await repository.fetchStage(id: sprint.stageID)
            else {
                throw AdaptationEngineError.sessionNotFound
            }
            let programID = stage.programID

            // 1. Resolve / create ConceptNodes by title (idempotent).
            //    Build a title → id map for the review-item step.
            var conceptIDsByTitle: [String: ConceptNode.ID] = [:]
            var recordedConceptIDs: [ConceptNode.ID] = []
            for concept in proposal.concepts {
                let id = try await repository.findOrCreateConceptNode(
                    programID: programID,
                    title: concept.title
                )
                conceptIDsByTitle[concept.title.lowercased()] = id
                recordedConceptIDs.append(id)
            }

            // 2. Upsert MasteryState for each concept. lastReviewedAt is
            //    "now" because the learner just engaged with the concept;
            //    nextReviewAt is left to whichever ReviewItem the LLM
            //    scheduled (may be nil if no review item targets this
            //    concept — that's fine, the review queue is the source
            //    of truth for "due next").
            let now = Date()
            for concept in proposal.concepts {
                guard let conceptID = conceptIDsByTitle[concept.title.lowercased()] else { continue }
                let nextReviewAt: Date? = proposal.reviewItems
                    .first(where: { $0.conceptTitle.lowercased() == concept.title.lowercased() })
                    .map { now.addingTimeInterval(TimeInterval($0.dueInDays) * 24 * 3600) }
                try await repository.upsertMasteryState(
                    conceptID: conceptID,
                    level: concept.masteryEstimate,
                    confidence: concept.confidence,
                    lastReviewedAt: now,
                    nextReviewAt: nextReviewAt
                )
            }

            // 3. Insert ReviewItem rows. Each review references the
            //    concept by lowercased title; if the validator passed
            //    that means the concept exists in `conceptIDsByTitle`.
            var recordedReviewItemIDs: [ReviewItem.ID] = []
            for item in proposal.reviewItems {
                guard let conceptID = conceptIDsByTitle[item.conceptTitle.lowercased()] else { continue }
                let dueAt = now.addingTimeInterval(TimeInterval(item.dueInDays) * 24 * 3600)
                let reviewID = try await repository.createReviewItem(
                    conceptID: conceptID,
                    dueAt: dueAt,
                    intervalDays: item.dueInDays
                )
                recordedReviewItemIDs.append(reviewID)
            }

            // 4. Persist the full proposal as an Artifact for Review
            //    Vault replay. JSON-encode rather than store individual
            //    columns: the artifact table is intentionally a pinboard
            //    (kind + free-form JSON) so we don't burn a migration
            //    every time the adaptation surface evolves.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let artifactData = try encoder.encode(proposal)
            let artifactJSON = String(decoding: artifactData, as: UTF8.self)
            let artifactID = try await repository.recordArtifact(
                sessionID: sessionID,
                attemptID: nil,
                kind: Artifact.Kind.sessionAdaptation,
                contentJSON: artifactJSON
            )

            // 5. Mark the session completed. Fires didCompleteSession +
            //    didChangeSessions hooks so CourseHome / Workspace
            //    react. Done LAST so any UI that gates on completion
            //    sees the artifact + reviews already in place when it
            //    refetches.
            try await repository.updateSessionStatus(
                id: sessionID,
                status: Session.Status.completed
            )

            // 6. Cascade: if every sibling session is completed, mark
            //    the sprint completed. Same for stage. We only escalate
            //    on the "completed" branch; other completion states
            //    leave the parents alone.
            if proposal.outcome.completion == AdaptationProposal.Outcome.Completion.completed {
                try await cascadeStatuses(
                    sprintID: sprint.id,
                    stageID: stage.id,
                    repository: repository
                )
            }

            return AdaptationSummary(
                sessionID: sessionID,
                programID: programID,
                outcomeCompletion: proposal.outcome.completion,
                summary: proposal.outcome.summary,
                recordedConceptIDs: recordedConceptIDs,
                recordedReviewItemIDs: recordedReviewItemIDs,
                recordedArtifactID: artifactID,
                nextStepKind: proposal.nextStep.kind,
                nextStepRationale: proposal.nextStep.rationale,
                proposal: proposal
            )
        } catch let error as AdaptationEngineError {
            throw error
        } catch {
            throw AdaptationEngineError.applyFailed(underlying: error)
        }
    }

    private static func cascadeStatuses(
        sprintID: Sprint.ID,
        stageID: Stage.ID,
        repository: LearningRepository
    ) async throws {
        let sprintSessions = try await repository.fetchSessions(forSprintID: sprintID)
        let allComplete = !sprintSessions.isEmpty && sprintSessions.allSatisfy {
            $0.status == Session.Status.completed
        }
        guard allComplete else { return }
        try await repository.updateSprintStatus(
            id: sprintID,
            status: Sprint.Status.completed
        )

        let stageSprints = try await repository.fetchSprints(forStageID: stageID)
        let allSprintsComplete = !stageSprints.isEmpty && stageSprints.allSatisfy {
            $0.status == Sprint.Status.completed
        }
        guard allSprintsComplete else { return }
        try await repository.updateStageStatus(
            id: stageID,
            status: Stage.Status.completed
        )
    }
}

extension Artifact.Kind {
    /// LLM-authored session-completion analysis written by
    /// `AdaptationEngine.apply`. Stored as JSON conforming to
    /// `AdaptationProposal`. Review Vault replays this on demand to
    /// show "what the tutor noticed about this session."
    public static let sessionAdaptation = "session_adaptation"
}
