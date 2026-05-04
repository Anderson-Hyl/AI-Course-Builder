import Foundation
import SQLiteData

/// Per-concept mastery. `level` and `confidence` are both in `[0, 1]`:
/// `level` is the evaluator's running estimate; `confidence` is how strong
/// that estimate is (low after one attempt, climbs with consistent
/// performance). `AdaptationEngine` reads both — high level + low
/// confidence still warrants a review.
///
/// `lastReviewedAt` / `nextReviewAt` drive spaced repetition. Nullable
/// so newly-encountered concepts that haven't been quizzed yet skip
/// scheduling.
@Table
public struct MasteryState: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var conceptID: ConceptNode.ID
    public var level: Double = 0
    public var confidence: Double = 0
    public var lastReviewedAt: Date?
    public var nextReviewAt: Date?
}
