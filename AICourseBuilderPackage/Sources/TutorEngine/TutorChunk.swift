import Foundation

/// Streaming event yielded from `TutorEngine.ask(...)`.
///
/// `text` is cumulative (mirrors `ChatEvent.text`) — each event carries
/// the full running response. UI consumers REPLACE the streaming tutor
/// bubble body on each event; they don't append.
public enum TutorChunk: Sendable, Equatable {
    case text(String)
    /// Terminal event. `stopReason` is the provider's wire-level reason
    /// (`end_turn`, `max_tokens`, etc.) — surfaced for diagnostics; the
    /// UI doesn't act on it in v1.
    case done(stopReason: String?)
}
