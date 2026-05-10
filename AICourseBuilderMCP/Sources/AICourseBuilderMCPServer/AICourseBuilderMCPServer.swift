import ChatClients
import Foundation
import HTTPTypes
import Hummingbird
import MCP
import NIOCore
import os

/// Hosts an MCP server inside the AICourseBuilder app over HTTP+SSE.
/// Wraps the official `swift-sdk` `StatefulHTTPServerTransport` with a
/// minimal Hummingbird 2 frontend that exposes `POST`, `GET`, and
/// `DELETE` on a single path (default `/mcp`).
///
/// The Claude Code CLI subprocess (spawned by `ClaudeCodeChatClient`)
/// connects here via `--mcp-config`, lists the active tool, and invokes
/// it. The active tool is whatever `MCPCallSession.shared` was acquired
/// for — typically the engine's currently-executing call (e.g.
/// `submit_blueprint` for `PlanningEngine.generateBlueprint`). When
/// the tool is invoked, the session captures the input JSON and
/// fulfills the awaiting engine.
///
/// ## Port-range binding
///
/// We walk `portRange` (default `8765…8770`) and pick the first port the
/// kernel accepts via a BSD-socket `bind(2)` probe. The chosen port is
/// published through `MCPServerState.shared` so the sidebar shows
/// truthful status and `ClaudeCodeChatClient` builds its `--mcp-config`
/// URL against the live port.
///
/// ## Single-session-per-instance workaround
///
/// Both `MCP.Server` and `StatefulHTTPServerTransport` track lifecycle
/// state on a single instance, so a second MCP client (or the same client
/// reconnecting after a `DELETE`) hits "Server is already initialized"
/// errors. To support multiple reconnects without restarting the whole
/// process, every incoming `initialize` request rebuilds the
/// `(mcpServer, transport)` pair from scratch and re-registers handlers.
public actor AICourseBuilderMCPServer {
    public static let defaultHost = "127.0.0.1"
    public static let defaultPort = 8765
    public static let defaultPath = "/mcp"
    /// Six consecutive ports starting at the canonical default. Wide
    /// enough to absorb a stale previous instance hanging onto the
    /// socket in TIME_WAIT, narrow enough that nothing legitimate is
    /// likely to be running nearby.
    public static let defaultPortRange: ClosedRange<Int> = 8765...8770
    public static let serverName = "AICourseBuilder"
    public static let serverVersion = "0.1.0"

    private let host: String
    private let portRange: ClosedRange<Int>
    private let path: String
    /// The port `start()` actually bound. `nil` until `.listening` or
    /// after `stop()`.
    private var boundPort: Int?
    /// Optional observer of lifecycle state. The app passes
    /// `MCPServerState.shared`.
    private let state: MCPServerState?
    private var mcpServer: Server
    private var transport: StatefulHTTPServerTransport
    private var httpServerTask: Task<Void, Never>?
    private var hasInitialized = false
    private let log = os.Logger(subsystem: "com.aicoursebuilder", category: "mcp")

    public init(
        host: String = AICourseBuilderMCPServer.defaultHost,
        portRange: ClosedRange<Int> = AICourseBuilderMCPServer.defaultPortRange,
        path: String = AICourseBuilderMCPServer.defaultPath,
        state: MCPServerState? = nil
    ) {
        self.host = host
        self.portRange = portRange
        self.path = path
        self.state = state
        self.mcpServer = Self.makeMCPServer()
        self.transport = StatefulHTTPServerTransport()
    }

    public var actualPort: Int? { boundPort }

    private static func makeMCPServer() -> Server {
        Server(
            name: serverName,
            version: serverVersion,
            // listChanged: true because the active tool changes per
            // `MCPCallSession.shared.acquire(toolSpec:)`. Clients that
            // honour `listChanged` re-fetch on the notification; CLI-
            // discovered tools are read fresh per `tools/list` either way.
            capabilities: .init(tools: .init(listChanged: true))
        )
    }

    // MARK: - Lifecycle

    public func start() async throws {
        await updateState(.starting)
        await registerHandlers()
        try await mcpServer.start(transport: transport)

        var selectedPort: Int?
        for candidate in portRange {
            if PortProbe.canBind(host: host, port: candidate, log: log) {
                selectedPort = candidate
                break
            }
        }
        guard let port = selectedPort else {
            let reason = "No available port in \(portRange.lowerBound)…\(portRange.upperBound)"
            log.error("\(reason, privacy: .public)")
            await updateState(.failed(reason: reason))
            throw MCPServerError.noPortAvailable(range: portRange)
        }

        boundPort = port
        let router = makeRouter(boundPort: port)
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(host, port: port),
                serverName: "AICourseBuilderMCP"
            )
        )
        let endpoint = "http://\(host):\(port)\(path)"
        log.info("MCP server listening on \(endpoint, privacy: .public)")

        httpServerTask = Task { [log, weak self] in
            do {
                try await app.runService()
            } catch is CancellationError {
                // normal shutdown
            } catch {
                let message = String(describing: error)
                log.error("HTTP server exited with error: \(message, privacy: .public)")
                await self?.markFailedIfRunning(reason: message)
            }
        }

        await updateState(.listening(port: port))
    }

    public func stop() async {
        httpServerTask?.cancel()
        httpServerTask = nil
        await mcpServer.stop()
        boundPort = nil
        await updateState(.idle)
    }

    /// Tear down any in-flight listener and rebuild the MCP server +
    /// transport so `start()` can use fresh instances, then restart.
    /// Sidebar's chip taps this in the failed state.
    public func restart() async throws {
        log.info("restarting MCP server")
        httpServerTask?.cancel()
        httpServerTask = nil
        boundPort = nil
        await mcpServer.stop()
        transport = StatefulHTTPServerTransport()
        mcpServer = Self.makeMCPServer()
        hasInitialized = false
        try await start()
    }

    /// Rebuilds `(mcpServer, transport)` so a new client can `initialize`
    /// cleanly. See the type docs for the single-session explanation.
    private func rebuildForNewClient() async {
        log.info("rebuilding MCP server + transport for a new client session")
        await mcpServer.stop()
        transport = StatefulHTTPServerTransport()
        mcpServer = Self.makeMCPServer()
        await registerHandlers()
        do {
            try await mcpServer.start(transport: transport)
        } catch {
            log.error("failed to restart MCP server: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - State plumbing

    private func updateState(_ readiness: MCPServerReadiness) async {
        guard let state else { return }
        await MainActor.run {
            state.readiness = readiness
        }
    }

    private func markFailedIfRunning(reason: String) async {
        guard boundPort != nil else { return }
        boundPort = nil
        await updateState(.failed(reason: reason))
    }

    // MARK: - Request handling

    fileprivate func handleMCPRequest(
        method: String,
        headers: [String: String],
        body: Data?,
        path: String
    ) async -> MCP.HTTPResponse {
        if method == "POST", let body, Self.isInitializeRequest(body) {
            if hasInitialized {
                await rebuildForNewClient()
            }
            hasInitialized = true
        }
        let mcpRequest = MCP.HTTPRequest(
            method: method,
            headers: headers,
            body: body,
            path: path
        )
        return await transport.handleRequest(mcpRequest)
    }

    private static func isInitializeRequest(_ data: Data) -> Bool {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let method = json["method"] as? String
        else { return false }
        return method == "initialize"
    }

    // MARK: - Tool dispatch (driven by MCPCallSession.shared)

    private func registerHandlers() async {
        let log = self.log

        // tools/list — read whatever tool the active session registered.
        // If no session is active, return an empty list so the CLI sees
        // "no tools available" rather than calling something stale.
        await mcpServer.withMethodHandler(ListTools.self) { _ in
            guard let spec = await MCPCallSession.shared.currentToolSpec() else {
                return ListTools.Result(tools: [])
            }
            do {
                let descriptor = try Self.makeToolDescriptor(spec)
                return ListTools.Result(tools: [descriptor])
            } catch {
                log.error("failed to build tool descriptor: \(String(describing: error), privacy: .public)")
                return ListTools.Result(tools: [])
            }
        }

        // tools/call — encode the arguments the CLI passed and hand them
        // to the active session. `tryFulfill` returns false if the call
        // doesn't match the registered tool name; we surface that as an
        // MCP-level error so the CLI sees a clear failure.
        await mcpServer.withMethodHandler(CallTool.self) { params in
            let argumentsValue: Value = .object(params.arguments ?? [:])
            let inputJSON: Data
            do {
                inputJSON = try JSONEncoder().encode(argumentsValue)
            } catch {
                log.error("failed to encode tool arguments: \(String(describing: error), privacy: .public)")
                return CallTool.Result(
                    content: [.text(
                        text: "Failed to encode arguments: \(error)",
                        annotations: nil,
                        _meta: nil
                    )],
                    isError: true
                )
            }
            let accepted = await MCPCallSession.shared.tryFulfill(
                name: params.name,
                inputJSON: inputJSON
            )
            if !accepted {
                return CallTool.Result(
                    content: [.text(
                        text: "Tool '\(params.name)' is not the active session's tool. The CLI subprocess called a tool name that doesn't match the engine's current request.",
                        annotations: nil,
                        _meta: nil
                    )],
                    isError: true
                )
            }
            return CallTool.Result(
                content: [.text(
                    text: "Captured.",
                    annotations: nil,
                    _meta: nil
                )],
                isError: false
            )
        }
    }

    private static func makeToolDescriptor(_ spec: ToolSpec) throws -> Tool {
        let schemaValue = try parseToolSchemaToValue(spec.inputSchemaJSON)
        return Tool(
            name: spec.name,
            description: spec.description,
            inputSchema: schemaValue
        )
    }

    /// Parse a JSON Schema string into MCP's `Value` type. Tries Codable
    /// first; falls back to a recursive `Any → Value` conversion via
    /// `JSONSerialization`.
    private static func parseToolSchemaToValue(_ json: String) throws -> Value {
        guard let data = json.data(using: .utf8) else {
            throw MCPServerError.invalidToolSchema(
                reason: "Tool schema JSON is not valid UTF-8"
            )
        }
        if let decoded = try? JSONDecoder().decode(Value.self, from: data) {
            return decoded
        }
        let any = try JSONSerialization.jsonObject(with: data, options: [])
        return convertAnyToValue(any)
    }

    private static func convertAnyToValue(_ any: Any) -> Value {
        switch any {
        case let dict as [String: Any]:
            var result: [String: Value] = [:]
            for (key, value) in dict {
                result[key] = convertAnyToValue(value)
            }
            return .object(result)
        case let array as [Any]:
            return .array(array.map(convertAnyToValue))
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case is NSNull:
            return .null
        default:
            // Fallthrough for NSNumber / other bridged types.
            if let number = any as? NSNumber {
                let typeID = String(cString: number.objCType)
                if typeID == "c" || typeID == "B" {
                    return .bool(number.boolValue)
                }
                if typeID == "q" || typeID == "i" || typeID == "l" || typeID == "s" {
                    return .int(number.intValue)
                }
                return .double(number.doubleValue)
            }
            return .null
        }
    }

    // MARK: - HTTP routing

    private func makeRouter(boundPort: Int) -> Router<BasicRequestContext> {
        let path = self.path
        let host = self.host
        let router = Router()

        router.post(RouterPath(path)) { [weak self] request, _ -> Response in
            let body = try await request.body.collect(upTo: .max)
            let data = Data(buffer: body)
            let headers = Self.collectHeaders(from: request.headers)
            let requestPath = request.uri.path
            guard let self else {
                return Response(status: .serviceUnavailable)
            }
            let mcpResponse = await self.handleMCPRequest(
                method: "POST",
                headers: headers,
                body: data,
                path: requestPath
            )
            return Self.convert(mcpResponse)
        }

        router.get(RouterPath(path)) { [weak self] request, _ -> Response in
            let headers = Self.collectHeaders(from: request.headers)
            let requestPath = request.uri.path
            guard let self else {
                return Response(status: .serviceUnavailable)
            }
            let mcpResponse = await self.handleMCPRequest(
                method: "GET",
                headers: headers,
                body: nil,
                path: requestPath
            )
            return Self.convert(mcpResponse)
        }

        router.delete(RouterPath(path)) { [weak self] request, _ -> Response in
            let headers = Self.collectHeaders(from: request.headers)
            let requestPath = request.uri.path
            guard let self else {
                return Response(status: .serviceUnavailable)
            }
            let mcpResponse = await self.handleMCPRequest(
                method: "DELETE",
                headers: headers,
                body: nil,
                path: requestPath
            )
            return Self.convert(mcpResponse)
        }

        // RFC 9728 protected-resource metadata. Claude Code's HTTP MCP
        // client probes this endpoint before sending any MCP request and
        // treats a 404 as "server misconfigured / auth failed". Returning
        // a document without `authorization_servers` signals "unprotected
        // resource" per the RFC, so the client skips OAuth and proceeds
        // to the normal MCP handshake.
        let metadataJSON = #"{"resource":"http://\#(host):\#(boundPort)\#(path)"}"#
        router.get(RouterPath("/.well-known/oauth-protected-resource")) { _, _ -> Response in
            Self.jsonResponse(metadataJSON)
        }
        router.get(RouterPath("/.well-known/oauth-protected-resource\(path)")) { _, _ -> Response in
            Self.jsonResponse(metadataJSON)
        }

        return router
    }

    // MARK: - HTTPFields / HTTPResponse bridging

    private nonisolated static func collectHeaders(from fields: HTTPFields) -> [String: String] {
        var result: [String: String] = [:]
        for field in fields {
            result[field.name.canonicalName] = field.value
        }
        return result
    }

    private nonisolated static func jsonResponse(_ body: String) -> Response {
        var headers = HTTPFields()
        if let contentType = HTTPField.Name("Content-Type") {
            headers.append(HTTPField(name: contentType, value: "application/json"))
        }
        return Response(
            status: .ok,
            headers: headers,
            body: ResponseBody(byteBuffer: ByteBuffer(string: body))
        )
    }

    private nonisolated static func convert(_ response: MCP.HTTPResponse) -> Response {
        let status = HTTPResponse.Status(code: response.statusCode)
        var httpFields = HTTPFields()
        for (name, value) in response.headers {
            if let fieldName = HTTPField.Name(name) {
                httpFields.append(HTTPField(name: fieldName, value: value))
            }
        }

        if case let .stream(stream, _) = response {
            let byteBuffers = stream.map { ByteBuffer(bytes: $0) }
            return Response(
                status: status,
                headers: httpFields,
                body: ResponseBody(asyncSequence: byteBuffers)
            )
        }
        if let data = response.bodyData {
            return Response(
                status: status,
                headers: httpFields,
                body: ResponseBody(byteBuffer: ByteBuffer(data: data))
            )
        }
        return Response(status: status, headers: httpFields, body: ResponseBody())
    }
}

public enum MCPServerError: LocalizedError {
    case noPortAvailable(range: ClosedRange<Int>)
    case invalidToolSchema(reason: String)

    public var errorDescription: String? {
        switch self {
        case .noPortAvailable(let range):
            return "No available port in \(range.lowerBound)…\(range.upperBound) for the MCP server. Try `lsof -iTCP:\(range.lowerBound)` to see what's occupying the range."
        case .invalidToolSchema(let reason):
            return "MCP server couldn't translate the tool's input schema: \(reason)"
        }
    }
}
