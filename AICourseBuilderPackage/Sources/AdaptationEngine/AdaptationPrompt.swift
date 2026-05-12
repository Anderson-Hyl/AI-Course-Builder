import ChatClients
import Foundation
import LearningModels

/// Loads the adaptation prompt + tool schema from `Bundle.module` once
/// and builds the `[ChatMessage]` payload for a given `AdaptationContext`.
/// Mirrors `PlanningPrompt`'s structure — system text + user text, with
/// the tool schema attached separately on the `ToolSpec`.
enum AdaptationPrompt {
    static let systemText: String = {
        guard let url = Bundle.module.url(forResource: "AdaptationPrompt", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            assertionFailure("AdaptationPrompt.txt missing from AdaptationEngine bundle resources")
            return ""
        }
        return text
    }()

    static let submitAdaptationSchemaJSON: String = {
        guard let url = Bundle.module.url(forResource: "SubmitAdaptationToolSchema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            assertionFailure("SubmitAdaptationToolSchema.json missing from AdaptationEngine bundle resources")
            return "{}"
        }
        return text
    }()

    static func buildMessages(context: AdaptationContext) -> [ChatMessage] {
        [
            ChatMessage(role: .system, content: systemText),
            ChatMessage(role: .user, content: userMessageText(context: context)),
        ]
    }

    private static func userMessageText(context: AdaptationContext) -> String {
        let stylesList = context.profile.learningStyles.sorted().joined(separator: ", ")
        let outcome = (context.profile.targetOutcome?.isEmpty == false) ? context.profile.targetOutcome! : "(not provided)"
        let knownConcepts: String = context.knownConceptTitles.isEmpty
            ? "(none yet — feel free to coin titles for what you observe)"
            : context.knownConceptTitles.joined(separator: ", ")

        var lines: [String] = []
        lines.append("Goal: \(context.goal.text)")
        lines.append("")
        lines.append("Learner profile:")
        lines.append("- Starting level: \(context.profile.startingLevel)")
        lines.append("- Weekly time budget: \(context.profile.weeklyTimeBudgetHours) hours")
        lines.append("- Learning styles: \(stylesList.isEmpty ? "(none specified)" : stylesList)")
        lines.append("- Target outcome: \(outcome)")
        lines.append("")
        lines.append("Program context:")
        lines.append("- Program summary: \(context.program.summary)")
        lines.append("- Stage: \(context.stage.title) — \(context.stage.intent)")
        lines.append("- Sprint: \(context.sprint.title) — \(context.sprint.focus)")
        lines.append("- Session: \(context.session.title)")
        lines.append("- Session objective: \(context.session.objective)")
        lines.append("")
        lines.append("Concepts already in this program's graph: \(knownConcepts)")
        lines.append("")
        lines.append("Session blocks the learner just worked through:")
        for block in context.blocks {
            lines.append("")
            lines.append("---")
            lines.append("Block \(block.order) · kind: \(block.kind)")
            lines.append("Payload JSON:")
            lines.append(block.payloadJSON)
            if let attempt = context.attempts[block.id] {
                lines.append("Attempt input JSON: \(attempt.inputJSON)")
                if let result = attempt.resultJSON {
                    lines.append("Attempt result JSON: \(result)")
                } else {
                    lines.append("Attempt result: (not yet scored)")
                }
            } else {
                lines.append("Attempt: (none — learner did not submit)")
            }
        }
        lines.append("")
        lines.append("Call submit_adaptation now with your structured analysis.")
        return lines.joined(separator: "\n")
    }
}
