import Foundation

/// Errors thrown by `AdaptationEngine.adapt`. The Session Workspace
/// reducer maps `.missingAPIKey` to the API-key sheet (same as
/// `PlanningEngine`); other cases surface inline in the Session
/// Workspace's adaptation overlay with a Retry / Skip choice.
public enum AdaptationEngineError: Error, LocalizedError, Sendable {
    case missingAPIKey
    case sessionNotFound
    case modelDidNotCallTool(stopReason: String?)
    case toolInputInvalidJSON(String)
    case proposalValidationFailed(reason: String)
    case applyFailed(underlying: Error)
    case cancelled
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No Anthropic API key on file. Tap the gear icon to add one."
        case .sessionNotFound:
            "The session this adaptation references is no longer on disk."
        case .modelDidNotCallTool(let stopReason):
            switch stopReason {
            case "max_tokens":
                "The model ran out of room before finishing the adaptation. Try again."
            case "refusal":
                "The model refused to generate an adaptation for this session. Skip and continue."
            case .some(let reason):
                "The model didn't return a structured adaptation (stop reason: \(reason)). Try again."
            case .none:
                "The model didn't return a structured adaptation. The custom base URL may be returning an unrecognized response format."
            }
        case .toolInputInvalidJSON(let reason):
            "The model returned invalid JSON: \(reason)"
        case .proposalValidationFailed(let reason):
            "The adaptation didn't pass validation: \(reason)"
        case .applyFailed(let error):
            "Couldn't apply the adaptation: \(error.localizedDescription)"
        case .cancelled:
            "Adaptation was cancelled."
        case .network(let message):
            "Network error: \(message)"
        }
    }
}

extension AdaptationEngineError: Equatable {
    public static func == (lhs: AdaptationEngineError, rhs: AdaptationEngineError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAPIKey, .missingAPIKey),
             (.sessionNotFound, .sessionNotFound),
             (.cancelled, .cancelled):
            true
        case (.modelDidNotCallTool(let a), .modelDidNotCallTool(let b)):
            a == b
        case (.toolInputInvalidJSON(let a), .toolInputInvalidJSON(let b)):
            a == b
        case (.proposalValidationFailed(let a), .proposalValidationFailed(let b)):
            a == b
        case (.applyFailed(let a), .applyFailed(let b)):
            a.localizedDescription == b.localizedDescription
        case (.network(let a), .network(let b)):
            a == b
        default:
            false
        }
    }
}
