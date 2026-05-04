import Foundation
import SQLiteData

/// A durable learner output — code attempts that compile, written
/// explanations, solved exercises, reflection notes. Per `PRD §11.3` /
/// `AGENTS §Learning logic.3`, artifacts are first-class progress signal
/// distinct from `Attempt` (one-shot answers) — they show what the
/// learner has *produced*.
///
/// References `sessionID` and/or `attemptID` (both optional). Most
/// artifacts will be attempt-derived; freestanding artifacts (notes
/// captured outside a specific attempt) reference only `sessionID`.
@Table
public struct Artifact: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sessionID: Session.ID?
    public var attemptID: Attempt.ID?
    /// Snake_case discriminator. Known kinds: `code_attempt`, `explanation`,
    /// `solved_exercise`, `reflection_note`. Open-ended — new kinds
    /// don't require a migration, just a renderer branch in Review Vault.
    public var kind: String = ""
    /// Kind-specific JSON payload. Free-form by design — the Artifact
    /// table is a pinboard; structured analytics happen in Attempt.
    public var contentJSON: String = "{}"
    public var createdAt: Date = Date()
}

extension Artifact {
    public enum Kind {
        public static let codeAttempt = "code_attempt"
        public static let explanation = "explanation"
        public static let solvedExercise = "solved_exercise"
        public static let reflectionNote = "reflection_note"

        public static let all: [String] = [codeAttempt, explanation, solvedExercise, reflectionNote]
    }
}
