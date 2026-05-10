import Foundation

/// Bridge between an engine's `chatClient.stream(.., .tool(name:))` call
/// and the in-process MCP server's `tools/list` + `tools/call` handlers.
///
/// **Why this exists.** Engines like `PlanningEngine` force a single tool
/// (`submit_blueprint`) and expect to capture its input as a typed
/// `CapturedToolCall`. The Anthropic API has native `tool_choice: tool`
/// support. The Claude Code CLI doesn't — its tool surface is MCP. To
/// bridge the two, `ClaudeCodeChatClient` registers the engine's
/// `ToolSpec` here as a single active session, spawns the CLI with
/// `--mcp-config` pointing at our in-process server, and awaits capture.
/// The server's request handlers read the active session for `tools/list`
/// and fulfill it on `tools/call`. The handle the engine receives streams
/// the captured input back asynchronously.
///
/// **Single-active-session.** Engines run serially in this app — there's
/// no concurrent planning + tutor + adaptation today — so we enforce
/// "at most one session in flight" in the actor. A second `acquire`
/// while one is active throws `serverBusy`. When multi-tool agent loops
/// arrive (Tutor / Adaptation), the bridge can grow into a queue or a
/// per-call ID scheme; v1 keeps it tight.
public actor MCPCallSession {
    public static let shared = MCPCallSession()

    private var active: ActiveSession?

    public init() {}

    // MARK: - Engine side

    /// Reserve the singleton for a single tool call. The returned handle
    /// can be awaited for the captured input; releasing it (or finishing
    /// the underlying stream) clears the slot.
    public func acquire(toolSpec: ToolSpec) throws -> Handle {
        if active != nil {
            throw MCPCallSessionError.serverBusy
        }
        let (stream, continuation) = AsyncStream<Result<CapturedToolCall, Error>>.makeStream()
        active = ActiveSession(toolSpec: toolSpec, continuation: continuation)
        return Handle(toolSpec: toolSpec, stream: stream)
    }

    /// Release the active session without yielding a capture. Safe to
    /// call from `defer` even if the session was already fulfilled —
    /// finishing an already-finished AsyncStream is a no-op.
    public func release() {
        active?.continuation.finish()
        active = nil
    }

    // MARK: - Server side

    /// Read the active tool spec for the server's `tools/list` handler.
    /// When no session is active, the server returns an empty tool list —
    /// the CLI subprocess will see "no tools available" and produce a
    /// terminal error rather than calling something stale.
    public func currentToolSpec() -> ToolSpec? {
        active?.toolSpec
    }

    /// Fulfill the active session with input the CLI passed to
    /// `tools/call`. Returns `true` when the call matched the active
    /// session's tool name, `false` otherwise (server should reply with
    /// an error in the false case so the CLI surfaces a clear failure).
    public func tryFulfill(name: String, inputJSON: Data) -> Bool {
        guard let active, active.toolSpec.name == name else { return false }
        let captured = CapturedToolCall(
            id: "mcp-\(UUID().uuidString)",
            name: name,
            inputJSON: inputJSON
        )
        active.continuation.yield(.success(captured))
        active.continuation.finish()
        self.active = nil
        return true
    }

    /// Surface a server-side failure (parse error, transport error, etc.)
    /// to the awaiting engine. Same semantics as `tryFulfill` but yields
    /// an error.
    public func failActive(_ error: Error) {
        guard let active else { return }
        active.continuation.yield(.failure(error))
        active.continuation.finish()
        self.active = nil
    }

    // MARK: - Types

    private struct ActiveSession {
        let toolSpec: ToolSpec
        let continuation: AsyncStream<Result<CapturedToolCall, Error>>.Continuation
    }

    public struct Handle: Sendable {
        public let toolSpec: ToolSpec
        let stream: AsyncStream<Result<CapturedToolCall, Error>>

        /// Block until the CLI invokes the registered tool. Throws
        /// `streamEnded` if the session is released without a capture
        /// (e.g. the subprocess exited without ever calling the tool).
        public func awaitCapture() async throws -> CapturedToolCall {
            for await result in stream {
                return try result.get()
            }
            throw MCPCallSessionError.streamEnded
        }
    }
}

public enum MCPCallSessionError: Error, LocalizedError, Sendable {
    case serverBusy
    case streamEnded

    public var errorDescription: String? {
        switch self {
        case .serverBusy:
            return "Another MCP call is already in flight. Engines run serially today; a second concurrent call shouldn't happen."
        case .streamEnded:
            return "MCP session ended without capturing a tool call. The Claude Code subprocess likely exited without invoking the registered tool."
        }
    }
}
