import Foundation

/// LLM-emitted adaptation, decoded from the `submit_adaptation` tool's
/// input JSON. Snake_case keys via explicit `CodingKeys` (matches the
/// rest of the LLM-facing schema). Carries four blocks the engine then
/// translates into repository writes:
///
/// - `outcome` — qualitative summary of how the session went; persisted
///   as an `Artifact` of kind `session_adaptation` for Review Vault.
/// - `concepts` — concepts the LLM identified across the session, with
///   a mastery estimate + confidence per concept. Each becomes a
///   `ConceptNode` (idempotent on title) plus a `MasteryState` upsert.
/// - `reviewItems` — flashcard-style spaced-repetition items. Each
///   becomes a `ReviewItem` row scheduled `due_in_days` from now.
/// - `nextStep` — the recommended next move (advance / recommend
///   review / recommend recovery). Currently informational; future
///   passes will translate `recommend_recovery` into a generated
///   recovery `Session` of `ReviewCard` blocks.
public struct AdaptationProposal: Codable, Equatable, Sendable {
    public var outcome: Outcome
    public var concepts: [Concept]
    public var reviewItems: [ReviewItem]
    public var nextStep: NextStep

    public enum CodingKeys: String, CodingKey {
        case outcome, concepts
        case reviewItems = "review_items"
        case nextStep = "next_step"
    }

    public struct Outcome: Codable, Equatable, Sendable {
        /// Qualitative completion label. See `Completion` for the three
        /// values the LLM is allowed to emit.
        public var completion: String
        public var summary: String
        public var highlights: [String]
        public var concerns: [String]

        public enum Completion {
            public static let completed = "completed"
            public static let partial = "partial"
            public static let struggling = "struggling"

            public static let all: [String] = [completed, partial, struggling]
        }

        public init(
            completion: String,
            summary: String,
            highlights: [String] = [],
            concerns: [String] = []
        ) {
            self.completion = completion
            self.summary = summary
            self.highlights = highlights
            self.concerns = concerns
        }
    }

    public struct Concept: Codable, Equatable, Sendable {
        public var title: String
        /// `[0, 1]` running mastery estimate. Validator clamps; the
        /// repository clamps again defensively.
        public var masteryEstimate: Double
        /// `[0, 1]` confidence in the mastery estimate. Low after one
        /// attempt, climbs with consistent performance.
        public var confidence: Double
        public var evidence: String

        public enum CodingKeys: String, CodingKey {
            case title, confidence, evidence
            case masteryEstimate = "mastery_estimate"
        }

        public init(
            title: String,
            masteryEstimate: Double,
            confidence: Double,
            evidence: String
        ) {
            self.title = title
            self.masteryEstimate = masteryEstimate
            self.confidence = confidence
            self.evidence = evidence
        }
    }

    public struct ReviewItem: Codable, Equatable, Sendable {
        /// Title of one of the `concepts` entries above. Resolves to a
        /// `ConceptNode.id` via the case-insensitive title lookup the
        /// applier runs against the program's concept set.
        public var conceptTitle: String
        /// SM-2-style cadence in days. Validator constrains to a small
        /// set of allowed intervals; the LLM picks based on signal
        /// strength (1 for "needs review tomorrow", 7 for "solid but
        /// worth re-checking").
        public var dueInDays: Int
        public var front: String
        public var back: String

        public enum CodingKeys: String, CodingKey {
            case front, back
            case conceptTitle = "concept_title"
            case dueInDays = "due_in_days"
        }

        public init(
            conceptTitle: String,
            dueInDays: Int,
            front: String,
            back: String
        ) {
            self.conceptTitle = conceptTitle
            self.dueInDays = dueInDays
            self.front = front
            self.back = back
        }
    }

    public struct NextStep: Codable, Equatable, Sendable {
        public var kind: String
        public var rationale: String

        public enum Kind {
            public static let advance = "advance"
            public static let recommendReviewSession = "recommend_review_session"
            public static let recommendRecovery = "recommend_recovery"

            public static let all: [String] = [advance, recommendReviewSession, recommendRecovery]
        }

        public init(kind: String, rationale: String) {
            self.kind = kind
            self.rationale = rationale
        }
    }

    public init(
        outcome: Outcome,
        concepts: [Concept] = [],
        reviewItems: [ReviewItem] = [],
        nextStep: NextStep
    ) {
        self.outcome = outcome
        self.concepts = concepts
        self.reviewItems = reviewItems
        self.nextStep = nextStep
    }
}

/// Engine-side digest returned by `AdaptationEngine.adapt`. Carries the
/// ids the engine actually wrote AND the validated proposal itself so
/// the Session Workspace can render a per-session digest card on exit
/// without re-fetching the artifact JSON from disk.
public struct AdaptationSummary: Sendable, Equatable {
    public let sessionID: UUID
    public let programID: UUID
    public let outcomeCompletion: String
    public let summary: String
    public let recordedConceptIDs: [UUID]
    public let recordedReviewItemIDs: [UUID]
    public let recordedArtifactID: UUID?
    public let nextStepKind: String
    public let nextStepRationale: String
    /// The full validated proposal the LLM emitted. Includes
    /// `outcome.highlights/concerns`, per-concept mastery estimates,
    /// and per-review flashcard fronts/backs that the workspace
    /// summary card renders. Kept here (rather than re-decoded from
    /// the persisted Artifact) so the post-adaptation surface doesn't
    /// pay an extra DB round-trip.
    public let proposal: AdaptationProposal

    public init(
        sessionID: UUID,
        programID: UUID,
        outcomeCompletion: String,
        summary: String,
        recordedConceptIDs: [UUID],
        recordedReviewItemIDs: [UUID],
        recordedArtifactID: UUID?,
        nextStepKind: String,
        nextStepRationale: String,
        proposal: AdaptationProposal
    ) {
        self.sessionID = sessionID
        self.programID = programID
        self.outcomeCompletion = outcomeCompletion
        self.summary = summary
        self.recordedConceptIDs = recordedConceptIDs
        self.recordedReviewItemIDs = recordedReviewItemIDs
        self.recordedArtifactID = recordedArtifactID
        self.nextStepKind = nextStepKind
        self.nextStepRationale = nextStepRationale
        self.proposal = proposal
    }
}
