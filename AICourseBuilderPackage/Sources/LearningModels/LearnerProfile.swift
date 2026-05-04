import Foundation
import SQLiteData

/// One learner using the app. v1 ships single-profile (one row per device);
/// schema supports multiple so a future "switch profile" surface is a
/// repository change, not a schema migration.
@Table
public struct LearnerProfile: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var displayName: String?
    /// Coarse self-reported starting level. Drives initial blueprint
    /// difficulty in `PlanningEngine`. String column with constants in
    /// `StartingLevel` for type-safety at call sites.
    public var startingLevel: String = StartingLevel.beginner
    /// Hours per week the learner expects to commit. Sets the granularity
    /// of session estimates (`Session.estimatedMinutes`) and how
    /// aggressively the planner expands near-term sessions.
    public var weeklyTimeBudgetHours: Int = 5
    /// JSON-encoded `[String]` of `LearningStyle` raw values. Codable
    /// arrays go through `payloadJSON`-style columns elsewhere; this is
    /// small enough that JSON-in-text keeps queries simple.
    public var learningStylesJSON: String = "[]"
    /// Optional one-line outcome the learner is targeting — e.g. "ship a
    /// small Haskell tool". Surfaced in adaptation prompts so generated
    /// sessions stay aligned with the user's goal beyond the topic.
    public var targetOutcome: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
}

extension LearnerProfile {
    /// String constants for the `startingLevel` column. Enum-style namespace
    /// so call sites read `LearnerProfile.StartingLevel.beginner` rather
    /// than a magic string.
    public enum StartingLevel {
        public static let beginner = "beginner"
        public static let intermediate = "intermediate"
        public static let advanced = "advanced"

        public static let all: [String] = [beginner, intermediate, advanced]
    }

    /// String constants for `learningStylesJSON` array members.
    public enum LearningStyle {
        public static let handsOn = "hands_on"
        public static let conceptual = "conceptual"
        public static let visual = "visual"
        public static let reading = "reading"

        public static let all: [String] = [handsOn, conceptual, visual, reading]
    }

    /// Decode `learningStylesJSON` into a `Set<String>` for UI binding.
    /// Returns an empty set on decode failure rather than throwing —
    /// the column is best-effort metadata, not load-bearing state.
    public var learningStyles: Set<String> {
        guard let data = learningStylesJSON.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(array)
    }

    /// Encode a `Set<String>` back into the JSON column. Sorted so the
    /// column value is deterministic across writes (helps test
    /// reproducibility and keeps diffs small in CloudKit metadata).
    public static func encodeLearningStyles(_ styles: Set<String>) -> String {
        let sorted = styles.sorted()
        guard let data = try? JSONEncoder().encode(sorted),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }
}
