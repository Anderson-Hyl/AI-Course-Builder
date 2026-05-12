import Foundation

/// Errors thrown by `TutorEngine.ask`. The SessionWorkspace reducer
/// maps these to an inline error bubble below the conversation, with a
/// retry affordance.
public enum TutorEngineError: Error, LocalizedError, Sendable, Equatable {
    case missingAPIKey
    case cancelled
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No Anthropic API key on file. Add one from the gear menu."
        case .cancelled:
            "Tutor response cancelled."
        case .network(let message):
            "Tutor unavailable: \(message)"
        }
    }
}
