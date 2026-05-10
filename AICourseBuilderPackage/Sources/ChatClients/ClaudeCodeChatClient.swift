import Foundation

// Claude Code CLI requires `Process` for subprocess spawn, which is macOS-
// only in Foundation (iOS / iPadOS / Catalyst do not ship a working
// Process). The entire wire implementation is gated here; the dispatch arm
// in `ChatClient.swift` also gates the `.claudeCode` provider case so iOS
// callers see it as "unavailable" rather than a compile error.
#if os(macOS)

/// Claude Code CLI wire implementation. Spawns the local `claude` binary
/// in headless mode and parses its stream-json event feed into
/// `ChatEvent`s. Adapted from SlideFlow's `ClaudeCodeClient.swift`, with
/// two notable differences:
///
/// 1. **No MCP server.** SlideFlow's CLI provider funnels tool calls
///    through an in-process HTTP MCP server that exposes the deck
///    mutation surface. AICourseBuilder doesn't have an MCP server yet —
///    instead, when an engine forces `tool_choice: .tool(name:)` we
///    inject the tool's JSON Schema into the system prompt and instruct
///    the CLI to emit a single JSON object. We then parse that JSON out
///    of the accumulated text and synthesize a `CapturedToolCall` so the
///    engine code path is provider-agnostic.
///
/// 2. **No subagent / multi-turn loop.** Engines in this codebase are
///    one-shot RPCs (PlanningEngine, etc.); we run `--print` once and
///    capture the full output.
///
/// The CLI binary is locked down with `--tools ""` so it can't reach the
/// user's filesystem, and `--permission-mode bypassPermissions` keeps
/// the headless run from blocking on prompts (safe because no tools are
/// reachable). The CLI inherits the user's own `claude` auth — there is
/// no API key on this path.
enum ClaudeCodeChatClient {
    static func stream(
        messages: [ChatMessage],
        model: LanguageModel,
        tools: [ToolSpec],
        toolChoice: ToolChoice,
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) async {
        do {
            try await runTurn(
                messages: messages,
                tools: tools,
                toolChoice: toolChoice,
                continuation: continuation
            )
        } catch is CancellationError {
            continuation.finish(throwing: CancellationError())
        } catch let error as ClaudeCodeError {
            continuation.finish(throwing: error)
        } catch let error as ChatClientError {
            continuation.finish(throwing: error)
        } catch {
            continuation.finish(throwing: ChatClientError.networkError(error.localizedDescription))
        }
    }

    /// Detects the installed `claude` CLI. Tries `/usr/bin/env which claude`
    /// first (which follows the user's PATH and is how installs land in
    /// practice), then falls back to a handful of known locations for the
    /// rare case where PATH is empty (e.g. launching from Finder under
    /// `LaunchServices` rather than a shell-spawned environment).
    static func detect() -> ClaudeCodeInstallation? {
        guard let binary = locateBinary() else { return nil }
        let version = captureFirstLine(executable: binary, arguments: ["--version"])
        return ClaudeCodeInstallation(binaryURL: binary, version: version)
    }

    // MARK: - Subprocess

    private static func runTurn(
        messages: [ChatMessage],
        tools: [ToolSpec],
        toolChoice: ToolChoice,
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) async throws {
        guard let installation = detect() else {
            throw ClaudeCodeError.notInstalled
        }

        let userPrompt = composePrompt(messages: messages)
        let systemPrompt = composeSystemPrompt(
            messages: messages,
            tools: tools,
            toolChoice: toolChoice
        )

        let process = Process()
        process.executableURL = installation.binaryURL
        var arguments: [String] = [
            "--print", userPrompt,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            // Disable every built-in tool the CLI ships with (Bash, Read,
            // Edit, Write, WebFetch, etc.) — we want a pure text response,
            // not an agent loop. Without this the model might decide to
            // shell out instead of emitting JSON.
            "--tools", "",
            // Headless runs cannot show permission prompts. With no tools
            // reachable, bypassPermissions is a safety no-op.
            "--permission-mode", "bypassPermissions",
        ]
        if !systemPrompt.isEmpty {
            arguments.append(contentsOf: ["--append-system-prompt", systemPrompt])
        }
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        var accumulated = ""

        for try await line in stdout.fileHandleForReading.bytes.lines {
            if Task.isCancelled {
                process.terminate()
                break
            }
            guard !line.isEmpty else { continue }
            guard
                let data = line.data(using: .utf8),
                let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            handle(event: event, accumulated: &accumulated, continuation: continuation)
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errText = String(
                decoding: stderr.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ClaudeCodeError.processFailed(
                exitCode: process.terminationStatus,
                stderr: errText
            )
        }

        let captured = synthesizeToolCall(
            from: accumulated,
            toolChoice: toolChoice
        )

        // The CLI doesn't surface input/output token counts on its terminal
        // event the same way the Anthropic API does. Engines only consult
        // `capturedToolCall` and `stopReason`, so leaving the token fields
        // nil is fine.
        let summary = TurnSummary(
            inputTokens: nil,
            outputTokens: nil,
            stopReason: captured == nil ? "end_turn" : "tool_use",
            capturedToolCall: captured
        )
        continuation.yield(.done(summary))
    }

    // MARK: - Stream-json event handling

    private static func handle(
        event: [String: Any],
        accumulated: inout String,
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) {
        let type = event["type"] as? String
        switch type {
        case "stream_event":
            guard
                let inner = event["event"] as? [String: Any],
                let delta = inner["delta"] as? [String: Any],
                (delta["type"] as? String) == "text_delta",
                let text = delta["text"] as? String,
                !text.isEmpty
            else { return }
            accumulated += text
            continuation.yield(.text(accumulated))

        case "result":
            // Terminal event. Most reps already saw the text via stream_event
            // deltas; fall back to `result` for very short replies where the
            // CLI didn't emit deltas.
            if accumulated.isEmpty,
               let finalText = event["result"] as? String,
               !finalText.isEmpty
            {
                accumulated = finalText
                continuation.yield(.text(accumulated))
            }

        default:
            // `system/init`, `system/status`, `assistant`, `user`, `rate_limit_event`,
            // `system/api_retry` — none of these need surfacing for engine
            // RPCs. The text and JSON we care about ride on stream_event +
            // result.
            return
        }
    }

    // MARK: - Prompt composition

    /// Combines all `system`-role messages with — when an engine forces a
    /// specific tool — an instruction to emit raw JSON matching that tool's
    /// schema. This is the AICourseBuilder workaround for the lack of an
    /// MCP server: the CLI doesn't natively support `tool_choice: tool`,
    /// so we lean on the prompt + post-process the text into a synthetic
    /// `CapturedToolCall`.
    private static func composeSystemPrompt(
        messages: [ChatMessage],
        tools: [ToolSpec],
        toolChoice: ToolChoice
    ) -> String {
        var parts = messages
            .filter { $0.role == .system }
            .map(\.content)
            .filter { !$0.isEmpty }

        if case .tool(let name) = toolChoice,
           let spec = tools.first(where: { $0.name == name })
        {
            parts.append(toolInstructionText(spec: spec))
        }

        return parts.joined(separator: "\n\n")
    }

    private static func toolInstructionText(spec: ToolSpec) -> String {
        """
        ## Required output format

        Respond with ONLY a single JSON object that conforms to the schema \
        below. Do NOT call any tools. Do NOT write explanatory text. Do NOT \
        wrap the JSON in a markdown fence. Output the raw JSON object as \
        your entire response, starting with `{` and ending with `}`.

        Tool: `\(spec.name)`
        Purpose: \(spec.description)

        JSON Schema:
        \(spec.inputSchemaJSON)
        """
    }

    /// The CLI takes a single prompt string via `--print`. Pass the latest
    /// user message as the prompt; flatten earlier turns into an
    /// instructional preface so the model has multi-turn context. Session
    /// resume (`--resume <id>`) is a future concern — keeping this stateless
    /// matches how AnthropicChatClient builds requests.
    private static func composePrompt(messages: [ChatMessage]) -> String {
        let nonSystem = messages.filter { $0.role != .system }
        guard let latest = nonSystem.last, latest.role == .user else {
            return nonSystem.last?.content ?? ""
        }
        if nonSystem.count <= 1 {
            return latest.content
        }
        var lines: [String] = ["Prior conversation:"]
        for message in nonSystem.dropLast() {
            let label: String = switch message.role {
            case .user: "User"
            case .assistant: "Assistant"
            case .system: "System"
            }
            lines.append("\(label): \(message.content)")
        }
        lines.append("")
        lines.append("Now respond to the user's latest message:")
        lines.append(latest.content)
        return lines.joined(separator: "\n")
    }

    // MARK: - Tool-call synthesis

    private static func synthesizeToolCall(
        from text: String,
        toolChoice: ToolChoice
    ) -> CapturedToolCall? {
        guard case .tool(let name) = toolChoice else { return nil }
        guard let json = extractJSONObject(from: text) else { return nil }
        return CapturedToolCall(
            id: "claude-code-\(UUID().uuidString)",
            name: name,
            inputJSON: json
        )
    }

    /// Tries three parses in order: the entire trimmed text as JSON, a
    /// fenced ```json``` (or unlabeled fenced) block, and the first
    /// balanced `{ ... }` substring. Returns the bytes of whichever parse
    /// produces a valid JSON object first.
    private static func extractJSONObject(from text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
        {
            return data
        }

        if let fenced = extractFencedJSON(from: trimmed) {
            return fenced
        }

        if let balanced = extractBalancedJSON(from: trimmed) {
            return balanced
        }

        return nil
    }

    private static func extractFencedJSON(from text: String) -> Data? {
        for opener in ["```json", "```JSON", "```"] {
            guard let openRange = text.range(of: opener) else { continue }
            let afterOpen = text[openRange.upperBound...]
            guard let closeRange = afterOpen.range(of: "```") else { continue }
            let inner = afterOpen[..<closeRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = inner.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
            {
                return data
            }
        }
        return nil
    }

    private static func extractBalancedJSON(from text: String) -> Data? {
        guard let firstBrace = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var endIndex: String.Index?

        for index in text.indices[firstBrace...] {
            let ch = text[index]
            if escape {
                escape = false
                continue
            }
            if inString {
                if ch == "\\" {
                    escape = true
                } else if ch == "\"" {
                    inString = false
                }
                continue
            }
            switch ch {
            case "\"":
                inString = true
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    endIndex = text.index(after: index)
                }
            default:
                continue
            }
            if endIndex != nil { break }
        }

        guard let endIndex else { return nil }
        let jsonText = String(text[firstBrace..<endIndex])
        guard let data = jsonText.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
        else { return nil }
        return data
    }

    // MARK: - Binary discovery

    private static func locateBinary() -> URL? {
        if let path = captureFirstLine(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["which", "claude"]
        ),
           !path.isEmpty,
           FileManager.default.isExecutableFile(atPath: path)
        {
            return URL(fileURLWithPath: path)
        }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let candidates = [
            "\(home)/.claude/local/claude",
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private static func captureFirstLine(executable: URL, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let text = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
}

// MARK: - Public types

public struct ClaudeCodeInstallation: Sendable, Equatable {
    public let binaryURL: URL
    public let version: String?

    public init(binaryURL: URL, version: String?) {
        self.binaryURL = binaryURL
        self.version = version
    }
}

public enum ClaudeCodeError: Error, LocalizedError, Sendable {
    case notInstalled
    case processFailed(exitCode: Int32, stderr: String)
    case modelDidNotOutputJSON(reason: String)

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Claude Code CLI isn't installed. Install it from https://docs.claude.com/en/docs/claude-code/quickstart, then run `claude login`."
        case .processFailed(let code, let stderr):
            let trimmed = stderr.isEmpty ? "" : " — \(stderr.prefix(240))"
            return "Claude Code exited with status \(code)\(trimmed)"
        case .modelDidNotOutputJSON(let reason):
            return "Claude Code didn't return parseable JSON: \(reason)"
        }
    }
}

#endif // os(macOS)
