import Foundation

/// Errors thrown by `PlanningEngine.generateBlueprint`. The reducer maps
/// these to the `PlanningErrorView` (retry / "Use Demo Program" / "Add
/// Key" buttons) so the UI is wired off the case, not a string.
public enum PlanningEngineError: Error, LocalizedError, Sendable {
    case missingAPIKey
    case modelDidNotCallTool
    case toolInputInvalidJSON(String)
    case proposalValidationFailed(reason: String)
    case translationFailed(underlying: Error)
    case cancelled
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No Anthropic API key on file. Tap the gear icon to add one."
        case .modelDidNotCallTool:
            "The model didn't return a structured plan. Try again."
        case .toolInputInvalidJSON(let reason):
            "The model returned invalid JSON: \(reason)"
        case .proposalValidationFailed(let reason):
            "The plan didn't pass validation: \(reason)"
        case .translationFailed(let error):
            "Couldn't save the plan: \(error.localizedDescription)"
        case .cancelled:
            "Planning was cancelled."
        case .network(let message):
            "Network error: \(message)"
        }
    }
}

extension PlanningEngineError: Equatable {
    /// Hand-rolled because `.translationFailed(underlying: Error)` carries
    /// a non-Equatable `Error`. Compare on case + the readable description
    /// so SwiftUI state observation works.
    public static func == (lhs: PlanningEngineError, rhs: PlanningEngineError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAPIKey, .missingAPIKey),
             (.modelDidNotCallTool, .modelDidNotCallTool),
             (.cancelled, .cancelled):
            true
        case (.toolInputInvalidJSON(let a), .toolInputInvalidJSON(let b)):
            a == b
        case (.proposalValidationFailed(let a), .proposalValidationFailed(let b)):
            a == b
        case (.translationFailed(let a), .translationFailed(let b)):
            a.localizedDescription == b.localizedDescription
        case (.network(let a), .network(let b)):
            a == b
        default:
            false
        }
    }
}
