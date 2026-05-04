import Foundation
import SQLiteData

/// One learner attempt at a `SessionBlock`. Captures the input the learner
/// produced, the evaluator's structured result (when available), and
/// timing so adaptation can reason about retry count + dwell time.
///
/// `inputJSON` and `resultJSON` shapes vary by block kind — see the typed
/// payloads in `AttemptPayloads.swift` (`AttemptInput.*`, `AttemptResult.*`).
/// Renderer + evaluator agree on the shape per kind; nothing else inspects
/// them.
@Table
public struct Attempt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var blockID: SessionBlock.ID
    /// The block's `kind` at the time of attempt — denormalized so a
    /// future renaming/deletion of the parent block doesn't orphan
    /// attempts to an unknown shape. (The block's current `kind` should
    /// match, but always trust this field on read.)
    public var kind: String = ""
    /// JSON-encoded learner input. For `multiple_choice`:
    /// `{"selected_index":2}`. Decode through `AttemptInput.*`.
    public var inputJSON: String = "{}"
    /// JSON-encoded evaluator result, nil while pending. Decode through
    /// `AttemptResult.*`.
    public var resultJSON: String?
    public var scoredAt: Date?
    public var createdAt: Date = Date()

    /// Public memberwise init for in-memory construction (optimistic
    /// in-flight attempts in the SessionWorkspace reducer, fixtures,
    /// tests). Production writes go through
    /// `LearningRepository.recordAttempt` + `Attempt.Draft` so triggers
    /// stamp `createdAt`; this init is for callers that build an
    /// `Attempt` value before/without persisting.
    public init(
        id: UUID,
        blockID: SessionBlock.ID,
        kind: String = "",
        inputJSON: String = "{}",
        resultJSON: String? = nil,
        scoredAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.blockID = blockID
        self.kind = kind
        self.inputJSON = inputJSON
        self.resultJSON = resultJSON
        self.scoredAt = scoredAt
        self.createdAt = createdAt
    }
}
