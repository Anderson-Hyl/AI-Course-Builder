import Foundation

/// Provider-agnostic tool description. `inputSchemaJSON` is the JSON
/// Schema string the wire client serializes verbatim into the provider's
/// tool-list field. We carry it as a raw string (not a typed schema
/// struct) because planning-grade tools have nested arrays + recursive
/// shapes that don't fit a flat `ToolPropertySchema` model.
public struct ToolSpec: Sendable {
    public let name: String
    public let description: String
    public let inputSchemaJSON: String

    public init(name: String, description: String, inputSchemaJSON: String) {
        self.name = name
        self.description = description
        self.inputSchemaJSON = inputSchemaJSON
    }
}

/// Mirrors Anthropic's `tool_choice` semantics. `.tool(name:)` forces the
/// model to call exactly that tool — used for one-shot structured output
/// (e.g. PlanningEngine's `submit_blueprint`).
public enum ToolChoice: Sendable, Equatable {
    case auto
    case any
    case tool(name: String)
}
