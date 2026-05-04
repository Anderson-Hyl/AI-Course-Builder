import Foundation
import SQLiteData

/// A short cluster of sessions inside a `Stage` — typically one focus area
/// the learner can tackle in a few days. Surfaced on the Home Dashboard's
/// "current sprint" card.
@Table
public struct Sprint: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var stageID: Stage.ID
    public var order: Int = 1
    public var title: String = ""
    /// One-sentence focus description — e.g. "Reading and writing type
    /// signatures". Shown on the Home Dashboard sprint card.
    public var focus: String = ""
    public var status: String = Sprint.Status.upcoming
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
}

extension Sprint {
    public enum Status {
        /// Not yet reached.
        public static let upcoming = "upcoming"
        /// Active sprint within the current stage.
        public static let inProgress = "in_progress"
        public static let completed = "completed"

        public static let all: [String] = [upcoming, inProgress, completed]
    }
}
