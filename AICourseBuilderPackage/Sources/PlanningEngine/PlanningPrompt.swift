import ChatClients
import Foundation
import LearningModels

/// Loads the planning prompt + tool schema from `Bundle.module` once and
/// builds the `[ChatMessage]` payload for a given goal + profile.
enum PlanningPrompt {
    static let systemText: String = {
        guard let url = Bundle.module.url(forResource: "PlanningPrompt", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            assertionFailure("PlanningPrompt.txt missing from PlanningEngine bundle resources")
            return ""
        }
        return text
    }()

    static let submitBlueprintSchemaJSON: String = {
        guard let url = Bundle.module.url(forResource: "SubmitBlueprintToolSchema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            assertionFailure("SubmitBlueprintToolSchema.json missing from PlanningEngine bundle resources")
            return "{}"
        }
        return text
    }()

    static func buildMessages(goal: LearningGoal, profile: LearnerProfile) -> [ChatMessage] {
        let stylesList = profile.learningStyles.sorted().joined(separator: ", ")
        let outcome = (profile.targetOutcome?.isEmpty == false) ? profile.targetOutcome! : "(not provided)"
        let userText = """
            Goal text (verbatim): \(goal.text)

            Learner profile:
            - Starting level: \(profile.startingLevel)
            - Weekly time budget: \(profile.weeklyTimeBudgetHours) hours
            - Learning styles: \(stylesList.isEmpty ? "(none specified)" : stylesList)
            - Target outcome: \(outcome)

            Produce the full structured plan via the submit_blueprint tool. Do not respond in prose — call the tool exactly once with the JSON.
            """
        return [
            ChatMessage(role: .system, content: systemText),
            ChatMessage(role: .user, content: userText),
        ]
    }
}
