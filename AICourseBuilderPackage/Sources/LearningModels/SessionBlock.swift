import Foundation
import SQLiteData

/// One block in a `Session`'s ordered sequence. Block kinds carry
/// kind-specific payloads serialized into `payloadJSON`; the renderer
/// dispatches on `kind` and decodes the payload to the matching struct.
///
/// **`schemaVersion` is mandatory.** Every payload struct ships with a
/// version literal; on read, the renderer compares against the version it
/// understands and degrades to a placeholder if the persisted payload is
/// newer than the renderer. Bumping the version is a breaking-change
/// signal — additive optional fields don't bump it.
///
/// Stored one-block-per-row (not as a JSON array on `Session`) so reorder
/// and per-block status updates touch one row, not the whole session
/// payload. Insert/delete triggers compact `order` so badges stay 01,
/// 02, 03 contiguous (mirrors SlideFlow's `slideInstances`).
@Table
public struct SessionBlock: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sessionID: Session.ID
    public var order: Int = 1
    /// Snake-case kind discriminator. See `BlockKind` for known values.
    public var kind: String = BlockKind.concept
    /// Schema version of `payloadJSON`. Each kind has its own version
    /// space — `multiple_choice@1` is independent of `concept@1`.
    public var schemaVersion: Int = 1
    /// Kind-specific payload encoded as JSON. Decoded via the typed
    /// payload struct in `BlockPayloads.swift`.
    public var payloadJSON: String = "{}"
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    /// Public memberwise init for in-memory construction (Previews,
    /// fixtures, tests). Swift's synthesized memberwise init defaults
    /// to `internal` visibility, which production write paths don't
    /// need (they go through `LearningRepository` + `SessionBlock.Draft`),
    /// but cross-module renderer fixtures and tests do.
    public init(
        id: UUID,
        sessionID: Session.ID,
        order: Int = 1,
        kind: String = BlockKind.concept,
        schemaVersion: Int = 1,
        payloadJSON: String = "{}",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.order = order
        self.kind = kind
        self.schemaVersion = schemaVersion
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// String constants for `SessionBlock.kind`. Snake_case to match the JSON
/// the LLM eventually produces. Keep this list in sync with the typed
/// payload structs in `BlockPayloads.swift`.
public enum BlockKind {
    public static let title = "title"
    public static let objective = "objective"
    public static let concept = "concept"
    public static let example = "example"
    public static let codeExercise = "code_exercise"
    public static let multipleChoice = "multiple_choice"
    public static let shortAnswer = "short_answer"
    public static let reflection = "reflection"
    public static let checkpoint = "checkpoint"
    public static let reviewCard = "review_card"

    public static let all: [String] = [
        title, objective, concept, example, codeExercise,
        multipleChoice, shortAnswer, reflection, checkpoint, reviewCard,
    ]
}
