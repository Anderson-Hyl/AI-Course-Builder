import Foundation
import Observation

/// Lifecycle status of the in-process MCP server. The server actor (in
/// the separate `AICourseBuilderMCP` package, macOS-only) writes through
/// `MCPServerState.shared` as it transitions; the sidebar reads here to
/// reflect actual server health rather than a hardcoded "always ready"
/// dot. `ClaudeCodeChatClient` also reads the active port through
/// `endpointURL` so its `--mcp-config` JSON points at whichever port
/// the range walker picked (default 8765, advances on collision).
public enum MCPServerReadiness: Sendable, Equatable {
    case idle
    case starting
    case listening(port: Int)
    case failed(reason: String)

    public var isReady: Bool {
        if case .listening = self { return true }
        return false
    }

    /// True when the last bind attempt failed. Drives the sidebar's
    /// "tap to retry" affordance — the chip becomes a button only in
    /// this state.
    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    /// The port currently bound, or nil for any non-listening state.
    /// Callers building a `--mcp-config` URL use this to point the CLI
    /// at the right port.
    public var listeningPort: Int? {
        if case .listening(let port) = self { return port }
        return nil
    }
}

/// Host-facing view of the in-process MCP server. Lives in `ChatClients`
/// so both the server (in `AICourseBuilderMCP`, macOS-only) and the UI
/// (sidebar chip) can read it without a circular dep. `MCPServerState`
/// itself has no MCP-specific dependencies — it's a tiny state holder.
///
/// `shared` is the singleton both the server and the UI bind to. The
/// server writes `readiness` through its lifecycle. `ClaudeCodeChatClient`
/// reads `endpointURL` just before spawning `claude --print` so its
/// `--mcp-config` JSON stays in sync with the actual bound port.
@MainActor
@Observable
public final class MCPServerState {
    public static let shared = MCPServerState()

    /// Host the server binds on. Loopback only — the MCP surface isn't
    /// meant to leave the machine.
    public static let host = "127.0.0.1"
    /// URL path the MCP endpoint is served under.
    public static let path = "/mcp"
    /// Port used for URL construction when the server isn't currently
    /// listening (idle / starting / failed). Falling back to the canonical
    /// default makes the CLI subprocess produce a "connection refused"
    /// error the UI surfaces, rather than silently using a wrong value.
    public static let defaultPort = 8765

    public var readiness: MCPServerReadiness = .idle

    /// Wired up by the macOS app target at launch to invoke
    /// `MCPServer.restart()` on the shared server instance. The sidebar
    /// chip taps this in the failed state to recover from a bind failure
    /// without relaunching. Stays nil on iPad (no server) and in tests.
    @ObservationIgnored
    public var onRetry: (@MainActor () -> Void)?

    public init() {}

    /// URL the CLI subprocess should point `--mcp-config` at. Uses the
    /// actual bound port when listening; otherwise falls back to the
    /// canonical default so failure surfaces as "connection refused" in
    /// the subprocess.
    public var endpointURL: String {
        let port = readiness.listeningPort ?? Self.defaultPort
        return "http://\(Self.host):\(port)\(Self.path)"
    }
}
