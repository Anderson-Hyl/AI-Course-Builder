import ChatClients
import Foundation

/// Loads the tutor system prompt from `Bundle.module` once and builds
/// the `[ChatMessage]` payload for a given conversation + context. The
/// prompt order is: persona/style system message, then a context system
/// message that describes the learner's current block, then the
/// alternating user/assistant turns ending with the latest user
/// question.
enum TutorPrompt {
    static let systemText: String = {
        guard let url = Bundle.module.url(forResource: "TutorPrompt", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            assertionFailure("TutorPrompt.txt missing from TutorEngine bundle resources")
            return ""
        }
        return text
    }()

    static func buildMessages(turns: [TutorTurn], context: TutorContext) -> [ChatMessage] {
        var messages: [ChatMessage] = [
            ChatMessage(role: .system, content: systemText),
            ChatMessage(role: .system, content: contextMessageText(context: context)),
        ]
        for turn in turns {
            let trimmed = turn.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            switch turn.role {
            case .user:
                messages.append(ChatMessage(role: .user, content: trimmed))
            case .tutor:
                messages.append(ChatMessage(role: .assistant, content: trimmed))
            }
        }
        return messages
    }

    private static func contextMessageText(context: TutorContext) -> String {
        var lines: [String] = ["Current lesson context:"]
        lines.append("- Session title: \(context.sessionTitle)")
        if !context.sessionObjective.isEmpty {
            lines.append("- Objective: \(context.sessionObjective)")
        }
        lines.append("- Block position: \(context.blockPositionDescription)")
        if let kind = context.currentBlockKind {
            lines.append("- Current block kind: \(kind)")
        }
        if let payload = context.currentBlockPayloadJSON, !payload.isEmpty {
            lines.append("- Current block payload (JSON):")
            lines.append(payload)
        }
        return lines.joined(separator: "\n")
    }
}
