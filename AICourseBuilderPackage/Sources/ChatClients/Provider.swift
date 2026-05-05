import Foundation

/// LLM provider identifier. v1 ships only Anthropic; the Claude Code CLI
/// provider lands in a follow-up pass and slots in here as `.claudeCode`
/// (`#if os(macOS)`-gated at the dispatch site).
public enum ProviderID: String, Sendable, Equatable, Codable, CaseIterable {
    case anthropic

    public var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        }
    }

    /// Hint shown in the API-key sheet placeholder so the user knows which
    /// shape of key to paste.
    public var keyPlaceholder: String {
        switch self {
        case .anthropic: "sk-ant-…"
        }
    }

    public var consoleURLString: String {
        switch self {
        case .anthropic: "https://console.anthropic.com/settings/keys"
        }
    }
}

/// Wire-level model selection. `id` is the provider's model id; `provider`
/// drives `ChatClient.liveValue`'s dispatch. Engines pin a model at the
/// call site (e.g. PlanningEngine uses `.claudeOpus47` for the structured
/// blueprint call); a model picker may surface this to the user later.
public struct LanguageModel: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let provider: ProviderID
    public let displayName: String

    public init(id: String, provider: ProviderID, displayName: String) {
        self.id = id
        self.provider = provider
        self.displayName = displayName
    }
}

extension LanguageModel {
    public static let claudeOpus47 = LanguageModel(
        id: "claude-opus-4-7",
        provider: .anthropic,
        displayName: "Claude Opus 4.7"
    )
}
