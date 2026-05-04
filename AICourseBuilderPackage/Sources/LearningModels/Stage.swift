import Foundation
import SQLiteData

/// A coarse phase of the program — e.g. for Haskell: "expressions, functions,
/// types". Owns `Sprint`s. Surfaced on the Program Map screen.
@Table
public struct Stage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var programID: ProgramBlueprint.ID
    public var order: Int = 1
    public var title: String = ""
    /// One-sentence description of what this stage moves the learner
    /// toward. Shown on Program Map cards.
    public var intent: String = ""
    public var status: String = Stage.Status.locked
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
}

extension Stage {
    public enum Status {
        /// Future stage — sprints not yet expanded. Displayed greyed-out
        /// on Program Map.
        public static let locked = "locked"
        /// Current stage — sprints expanded, learner is working through it.
        public static let inProgress = "in_progress"
        /// All sprints completed.
        public static let completed = "completed"

        public static let all: [String] = [locked, inProgress, completed]
    }
}
