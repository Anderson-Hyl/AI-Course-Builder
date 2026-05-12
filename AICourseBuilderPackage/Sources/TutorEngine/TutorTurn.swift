import Foundation

/// One turn in a tutor conversation. The `SessionWorkspace` reducer keeps
/// an `IdentifiedArrayOf<TutorTurn>` and passes the whole array to
/// `TutorEngine.ask` on every send so the model sees the full
/// back-and-forth. `text` is mutated in place on the streaming tutor
/// turn — the reducer reaches into the array by `id` and replaces the
/// cumulative content as `TutorChunk.text` chunks arrive.
public struct TutorTurn: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let role: Role
    public var text: String

    public enum Role: Sendable, Equatable, Hashable {
        case user
        case tutor
    }

    public init(id: UUID, role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
