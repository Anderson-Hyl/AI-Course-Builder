import Foundation

/// LLM provider identifier. Two providers ship today:
///
/// - `.anthropic` — URLSession + SSE against `/v1/messages`. Runs on iPad
///   and Mac (Designed for iPad). The default for the shipping iPad target.
/// - `.claudeCode` — `#if os(macOS)`-gated. Spawns the local `claude` CLI
///   via `Process` for fast dev iteration without burning API credits.
///   The default for the macOS dev target.
public enum ProviderID: String, Sendable, Equatable, Codable, CaseIterable {
    case anthropic
    case claudeCode = "claude-code"

    public var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .claudeCode: "Claude Code CLI"
        }
    }

    /// Hint shown in the API-key sheet placeholder so the user knows which
    /// shape of key to paste. CLI provider doesn't take a key — its auth
    /// lives in the user's `claude` CLI session — so the placeholder is
    /// empty.
    public var keyPlaceholder: String {
        switch self {
        case .anthropic: "sk-ant-…"
        case .claudeCode: ""
        }
    }

    public var consoleURLString: String {
        switch self {
        case .anthropic: "https://console.anthropic.com/settings/keys"
        case .claudeCode: "https://docs.claude.com/en/docs/claude-code/quickstart"
        }
    }

    /// True when the provider authenticates via the `APIKeyStore` rather
    /// than out-of-band (e.g. `claude login` for the CLI). Engines use
    /// this to decide whether a missing key should fast-fail before the
    /// chat round-trip.
    public var requiresAPIKey: Bool {
        switch self {
        case .anthropic: true
        case .claudeCode: false
        }
    }
}

/// Wire-level model selection. `id` is the provider's model id; `provider`
/// drives `ChatClient.liveValue`'s dispatch. Engines call
/// `LanguageModel.defaultPlanningModel` so the planning round-trip picks
/// the platform's preferred wire (CLI on macOS dev, API on iPad).
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

    /// Marker model for the local Claude Code CLI provider. The `id` is
    /// not sent over the wire — the CLI subprocess inherits the user's
    /// own `claude` defaults — but `provider == .claudeCode` is what
    /// `ChatClient.liveValue` switches on.
    public static let claudeCodeCli = LanguageModel(
        id: "claude-code-cli",
        provider: .claudeCode,
        displayName: "Claude Code CLI"
    )

    /// Platform-default model engines use for planning calls. On macOS
    /// dev builds we route through the local Claude Code CLI so iteration
    /// doesn't burn API credits; everywhere else (iPad shipping, Mac
    /// Designed-for-iPad) we hit Anthropic directly.
    public static var defaultPlanningModel: LanguageModel {
        #if os(macOS)
        return .claudeCodeCli
        #else
        return .claudeOpus47
        #endif
    }
}
