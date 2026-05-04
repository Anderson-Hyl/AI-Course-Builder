import Foundation
import SQLiteData

/// One teachable unit — what the learner sits down to do today. Owns a list
/// of `SessionBlock`s rendered in order. Displayed on the Session Workspace
/// screen.
@Table
public struct Session: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sprintID: Sprint.ID
    public var order: Int = 1
    public var title: String = ""
    /// One-sentence learning objective shown at the top of the session.
    /// Anchors the learner before they dive into the blocks.
    public var objective: String = ""
    /// Planner's estimate of how long this session takes, used for the
    /// "today's session · ~15m" hint and to gauge weekly time-budget fit.
    public var estimatedMinutes: Int = 15
    public var status: String = Session.Status.notStarted
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
}

extension Session {
    public enum Status {
        public static let notStarted = "not_started"
        public static let inProgress = "in_progress"
        public static let completed = "completed"
        /// Adaptation engine deferred this session pending a recovery
        /// session or review block.
        public static let deferred = "deferred"

        public static let all: [String] = [notStarted, inProgress, completed, deferred]
    }
}
