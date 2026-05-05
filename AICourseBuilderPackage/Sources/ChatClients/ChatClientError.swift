import Foundation

/// Errors thrown by the `ChatClient` layer. Engines catch these at the
/// top of their pipelines and translate into engine-specific errors so
/// the UI can show actionable copy (e.g. PlanningEngineError.missingAPIKey
/// → API key sheet auto-opens).
public enum ChatClientError: Error, LocalizedError, Sendable {
    case missingAPIKey(ProviderID)
    case invalidAPIKey
    case rateLimited(retryAfter: TimeInterval?)
    case httpError(status: Int, body: String?)
    case parseError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "No \(provider.displayName) API key on file. Tap the gear icon to add one."
        case .invalidAPIKey:
            "The API key was rejected. Double-check the key and try again."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Rate limited. Try again in \(Int(retryAfter))s."
            } else {
                "Rate limited. Try again shortly."
            }
        case .httpError(let status, let body):
            "HTTP \(status): \(body ?? "(no body)")"
        case .parseError(let detail):
            "Couldn't parse the model's response: \(detail)"
        case .networkError(let detail):
            "Network error: \(detail)"
        }
    }
}
