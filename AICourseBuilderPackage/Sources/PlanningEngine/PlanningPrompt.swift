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

    static let submitOutlineSchemaJSON: String = {
        guard let url = Bundle.module.url(forResource: "SubmitOutlineToolSchema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            assertionFailure("SubmitOutlineToolSchema.json missing from PlanningEngine bundle resources")
            return "{}"
        }
        return text
    }()

    static func buildMessages(goal: LearningGoal, profile: LearnerProfile) -> [ChatMessage] {
        let userText = userMessageText(goal: goal, profile: profile, scope: .full)
        return [
            ChatMessage(role: .system, content: systemText),
            ChatMessage(role: .user, content: userText),
        ]
    }

    static func buildOutlineMessages(goal: LearningGoal, profile: LearnerProfile) -> [ChatMessage] {
        let userText = userMessageText(goal: goal, profile: profile, scope: .outline)
        return [
            ChatMessage(role: .system, content: systemText),
            ChatMessage(role: .user, content: userText),
        ]
    }

    private enum Scope { case outline, full }

    private static func userMessageText(
        goal: LearningGoal,
        profile: LearnerProfile,
        scope: Scope
    ) -> String {
        let stylesList = profile.learningStyles.sorted().joined(separator: ", ")
        let outcome = (profile.targetOutcome?.isEmpty == false) ? profile.targetOutcome! : "(not provided)"
        let directive: String = switch scope {
        case .outline:
            "Produce ONLY the program summary, normalized topic, and the full ordered stage list (4-8 stages with title + intent). Do NOT generate sprints, sessions, or blocks at this stage — those come after the learner confirms the outline. Use the submit_outline tool. Respond ONLY via the tool call."
        case .full:
            "Produce the full structured plan via the submit_blueprint tool. Do not respond in prose — call the tool exactly once with the JSON."
        }
        return """
            Goal text (verbatim): \(goal.text)

            Learner profile:
            - Starting level: \(profile.startingLevel)
            - Weekly time budget: \(profile.weeklyTimeBudgetHours) hours
            - Learning styles: \(stylesList.isEmpty ? "(none specified)" : stylesList)
            - Target outcome: \(outcome)

            \(directive)
            """
    }
}
