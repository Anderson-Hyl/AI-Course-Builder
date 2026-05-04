import Foundation
import SQLiteData

/// One learner attempt at a `SessionBlock`. Captures the input the learner
/// produced, the evaluator's structured result (when available), and
/// timing so adaptation can reason about retry count + dwell time.
///
/// `inputJSON` and `resultJSON` shapes vary by block kind — they mirror the
/// payload structs in `BlockPayloads.swift`. Renderer + evaluator agree on
/// the shape per kind; nothing else inspects them.
@Table
public struct Attempt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var blockID: SessionBlock.ID
    /// The block's `kind` at the time of attempt — denormalized so a
    /// future renaming/deletion of the parent block doesn't orphan
    /// attempts to an unknown shape. (The block's current `kind` should
    /// match, but always trust this field on read.)
    public var kind: String = ""
    /// JSON-encoded learner input. For `multiple_choice`: `{"index":2}`.
    /// For `short_answer`: `{"text":"…"}`. For `code_exercise`:
    /// `{"code":"…","language":"haskell"}`.
    public var inputJSON: String = "{}"
    /// JSON-encoded evaluator result, nil while pending. Common shape:
    /// `{"correct":true,"score":1.0,"feedback":"…","mistakes":[…]}`.
    public var resultJSON: String?
    public var scoredAt: Date?
    public var createdAt: Date = Date()
}
