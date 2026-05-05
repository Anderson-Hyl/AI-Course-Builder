import Foundation

/// One message in a chat history. Engines compose `[ChatMessage]` and hand
/// it to `ChatClient.stream(...)`; the Anthropic client splits the
/// `.system` partition into the request's top-level `system` field and
/// sends the rest as `messages: [{ role, content }]`.
public struct ChatMessage: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var role: Role
    public var content: String

    public init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    public enum Role: String, Sendable, Equatable, Codable {
        case system
        case user
        case assistant
    }
}
