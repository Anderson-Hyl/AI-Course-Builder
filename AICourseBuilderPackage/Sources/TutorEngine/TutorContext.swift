import Foundation

/// Snapshot of the learner's current location in a session, handed to
/// `TutorEngine.ask(...)` on every turn so the model knows what block
/// the learner is looking at. Built by the SessionWorkspace reducer
/// from the live state right before each send.
///
/// Context is rebuilt per send (not stamped once at conversation start)
/// because the learner can navigate between blocks while the tutor
/// panel is open — a stale context would let the model give a hint
/// about the wrong block.
public struct TutorContext: Sendable, Equatable {
    public let sessionTitle: String
    public let sessionObjective: String
    /// `BlockKind` snake_case string (e.g. `concept`, `multiple_choice`).
    /// Nil when the workspace is still loading.
    public let currentBlockKind: String?
    /// Raw `SessionBlock.payloadJSON` for the current block. Passed
    /// through verbatim so the model sees question text, options,
    /// rubric, etc. Defense-in-depth on answer-leakage lives in the
    /// system prompt ("guide, don't reveal").
    public let currentBlockPayloadJSON: String?
    /// Human-readable position string for the context line (e.g.
    /// "Block 3 of 8").
    public let blockPositionDescription: String

    public init(
        sessionTitle: String,
        sessionObjective: String,
        currentBlockKind: String?,
        currentBlockPayloadJSON: String?,
        blockPositionDescription: String
    ) {
        self.sessionTitle = sessionTitle
        self.sessionObjective = sessionObjective
        self.currentBlockKind = currentBlockKind
        self.currentBlockPayloadJSON = currentBlockPayloadJSON
        self.blockPositionDescription = blockPositionDescription
    }
}
