import Foundation
import SQLiteData

/// The user-stated learning goal — e.g. "I want to learn Haskell". One goal
/// per `LearnerProfile` is the v1 expectation; schema supports many so
/// archived goals can survive without manual deletion.
@Table
public struct LearningGoal: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var profileID: LearnerProfile.ID
    /// Verbatim user input. The user's words survive — `PlanningEngine`
    /// reads `normalizedTopic` for prompting but presents `text` back to
    /// the user verbatim.
    public var text: String = ""
    /// LLM-normalized topic slug (e.g. "haskell"). Nullable until the
    /// planner runs. Helps cluster goals across users for retrieval and
    /// prompts that reuse subject-specific framing.
    public var normalizedTopic: String?
    public var status: String = LearningGoal.Status.draft
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
}

extension LearningGoal {
    public enum Status {
        /// User has entered the goal but the blueprint hasn't been
        /// generated yet. Goal Intake → Start Learning lands here briefly.
        public static let draft = "draft"
        /// Blueprint is generated and the user is actively progressing.
        public static let active = "active"
        /// User explicitly archived the goal — it stays queryable but no
        /// adaptation runs against it.
        public static let archived = "archived"

        public static let all: [String] = [draft, active, archived]
    }
}
