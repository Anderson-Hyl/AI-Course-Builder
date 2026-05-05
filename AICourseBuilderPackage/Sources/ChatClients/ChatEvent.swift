import Foundation

/// Streaming event yielded from `ChatClient.stream(...)`.
///
/// **`text` is cumulative**, not delta — each event carries the full
/// running concatenation of every text block seen so far. UI consumers
/// REPLACE the assistant message body on each event; they don't append.
/// Engines that only care about structured output (e.g. PlanningEngine)
/// ignore `.text` entirely and act on `.done(summary).capturedToolCall`.
public enum ChatEvent: Sendable, Equatable {
    case text(String)
    case done(TurnSummary)
}

/// Terminal event payload. `capturedToolCall` is non-nil whenever the
/// model emitted at least one `tool_use` content block — the runner
/// captures the first such block (engines that force a single tool via
/// `tool_choice: .tool(name:)` see exactly one).
public struct TurnSummary: Sendable, Equatable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var stopReason: String?
    public var capturedToolCall: CapturedToolCall?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        stopReason: String? = nil,
        capturedToolCall: CapturedToolCall? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.stopReason = stopReason
        self.capturedToolCall = capturedToolCall
    }
}

/// One typed tool call captured from the stream. `inputJSON` is the raw
/// concatenation of every `input_json_delta` partial-JSON chunk for the
/// tool block. Engines decode it against their tool-specific Codable
/// shape (e.g. `BlueprintProposal`).
public struct CapturedToolCall: Sendable, Equatable {
    public let id: String
    public let name: String
    public let inputJSON: Data

    public init(id: String, name: String, inputJSON: Data) {
        self.id = id
        self.name = name
        self.inputJSON = inputJSON
    }
}
