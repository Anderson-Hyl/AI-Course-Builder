import Foundation

/// Anthropic Messages API streaming runner. POSTs to `/v1/messages` with
/// `stream: true`, async-iterates the SSE byte stream, and yields
/// `ChatEvent.text(cumulative)` on every `text_delta` plus a terminal
/// `.done(TurnSummary)` carrying the captured tool call (if any), token
/// usage, and stop reason.
///
/// Single-pass: we don't run a multi-turn tool loop here because every
/// engine in this app is a one-shot RPC (e.g. PlanningEngine forces
/// `tool_choice: { type: tool, name: "submit_blueprint" }` and the model
/// returns one structured tool call). When an interactive agent surface
/// arrives (Tutor panel, Adaptation), that loop lives in the engine, not
/// here — same shape SlideFlow uses for its chat drawer.
enum AnthropicChatClient {
    static func stream(
        messages: [ChatMessage],
        model: LanguageModel,
        apiKey: String,
        tools: [ToolSpec],
        toolChoice: ToolChoice,
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) async {
        do {
            try await runTurn(
                messages: messages,
                model: model,
                apiKey: apiKey,
                tools: tools,
                toolChoice: toolChoice,
                continuation: continuation
            )
        } catch is CancellationError {
            continuation.finish(throwing: CancellationError())
        } catch let error as ChatClientError {
            continuation.finish(throwing: error)
        } catch {
            continuation.finish(throwing: ChatClientError.networkError(error.localizedDescription))
        }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    private static func runTurn(
        messages: [ChatMessage],
        model: LanguageModel,
        apiKey: String,
        tools: [ToolSpec],
        toolChoice: ToolChoice,
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.httpBody = try buildRequestBody(
            messages: messages,
            model: model,
            tools: tools,
            toolChoice: toolChoice
        )

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChatClientError.networkError("Non-HTTP response")
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw ChatClientError.invalidAPIKey
        case 429:
            let retryAfter = (http.value(forHTTPHeaderField: "retry-after"))
                .flatMap(TimeInterval.init)
            throw ChatClientError.rateLimited(retryAfter: retryAfter)
        default:
            let body = try? await readAllBytes(bytes)
            throw ChatClientError.httpError(status: http.statusCode, body: body)
        }

        var blocks: [Int: BlockState] = [:]
        var inputTokens: Int?
        var outputTokens: Int?
        var stopReason: String?

        for try await line in bytes.lines {
            if line.isEmpty || line.hasPrefix(":") { continue }
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst("data: ".count))
            guard let data = payload.data(using: .utf8) else { continue }
            guard let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data) else {
                // Drop unrecognized event shapes (ping, future event types).
                continue
            }

            switch event {
            case .messageStart(let start):
                inputTokens = start.message.usage?.inputTokens ?? inputTokens

            case .contentBlockStart(let start):
                switch start.contentBlock {
                case .text:
                    blocks[start.index] = .text("")
                case .toolUse(let id, let name):
                    blocks[start.index] = .toolUse(id: id, name: name, jsonBuffer: "")
                }

            case .contentBlockDelta(let delta):
                switch delta.delta {
                case .textDelta(let text):
                    if case .text(let existing) = blocks[delta.index] {
                        blocks[delta.index] = .text(existing + text)
                    } else {
                        // Server sent a delta before block_start — be lenient.
                        blocks[delta.index] = .text(text)
                    }
                    let cumulative = concatenatedText(blocks: blocks)
                    continuation.yield(.text(cumulative))
                case .inputJsonDelta(let partial):
                    if case .toolUse(let id, let name, let buffer) = blocks[delta.index] {
                        blocks[delta.index] = .toolUse(id: id, name: name, jsonBuffer: buffer + partial)
                    }
                }

            case .contentBlockStop:
                continue

            case .messageDelta(let delta):
                if let reason = delta.delta.stopReason { stopReason = reason }
                if let usage = delta.usage {
                    if let value = usage.outputTokens { outputTokens = value }
                    if let value = usage.inputTokens { inputTokens = value }
                }

            case .messageStop:
                continue

            case .ping, .errorEvent:
                continue
            }
        }

        let captured = firstToolUseBlock(blocks: blocks)
        let summary = TurnSummary(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            stopReason: stopReason,
            capturedToolCall: captured
        )
        continuation.yield(.done(summary))
    }

    // MARK: - Helpers

    private static func concatenatedText(blocks: [Int: BlockState]) -> String {
        blocks
            .keys
            .sorted()
            .compactMap { index -> String? in
                if case .text(let value) = blocks[index] { return value }
                return nil
            }
            .joined()
    }

    private static func firstToolUseBlock(blocks: [Int: BlockState]) -> CapturedToolCall? {
        for index in blocks.keys.sorted() {
            if case .toolUse(let id, let name, let buffer) = blocks[index] {
                let bytes = (buffer.isEmpty ? "{}" : buffer).data(using: .utf8) ?? Data()
                return CapturedToolCall(id: id, name: name, inputJSON: bytes)
            }
        }
        return nil
    }

    private static func readAllBytes(_ bytes: URLSession.AsyncBytes) async throws -> String? {
        var collected = Data()
        for try await byte in bytes {
            collected.append(byte)
            if collected.count > 16_000 { break }
        }
        return String(data: collected, encoding: .utf8)
    }

    private static func buildRequestBody(
        messages: [ChatMessage],
        model: LanguageModel,
        tools: [ToolSpec],
        toolChoice: ToolChoice
    ) throws -> Data {
        let systemText = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
        let nonSystem = messages.filter { $0.role != .system }

        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": 8192,
            "stream": true,
            "messages": nonSystem.map { message -> [String: Any] in
                [
                    "role": message.role.rawValue,
                    "content": message.content,
                ]
            },
        ]
        if !systemText.isEmpty {
            body["system"] = systemText
        }
        if !tools.isEmpty {
            body["tools"] = try tools.map { spec -> [String: Any] in
                guard let schemaData = spec.inputSchemaJSON.data(using: .utf8),
                      let schemaObject = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any]
                else {
                    throw ChatClientError.parseError("Tool '\(spec.name)' has invalid input_schema JSON")
                }
                return [
                    "name": spec.name,
                    "description": spec.description,
                    "input_schema": schemaObject,
                ]
            }
            switch toolChoice {
            case .auto:
                body["tool_choice"] = ["type": "auto"]
            case .any:
                body["tool_choice"] = ["type": "any"]
            case .tool(let name):
                body["tool_choice"] = ["type": "tool", "name": name]
            }
        }
        return try JSONSerialization.data(withJSONObject: body, options: [])
    }
}

// MARK: - Per-block accumulator

private enum BlockState: Sendable {
    case text(String)
    case toolUse(id: String, name: String, jsonBuffer: String)
}

// MARK: - Wire types

private enum AnthropicStreamEvent: Decodable {
    case messageStart(MessageStart)
    case contentBlockStart(ContentBlockStart)
    case contentBlockDelta(ContentBlockDelta)
    case contentBlockStop(index: Int)
    case messageDelta(MessageDelta)
    case messageStop
    case ping
    case errorEvent

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let single = try decoder.singleValueContainer()
        switch type {
        case "message_start":
            self = .messageStart(try single.decode(MessageStart.self))
        case "content_block_start":
            self = .contentBlockStart(try single.decode(ContentBlockStart.self))
        case "content_block_delta":
            self = .contentBlockDelta(try single.decode(ContentBlockDelta.self))
        case "content_block_stop":
            let stop = try single.decode(IndexCarrier.self)
            self = .contentBlockStop(index: stop.index)
        case "message_delta":
            self = .messageDelta(try single.decode(MessageDelta.self))
        case "message_stop":
            self = .messageStop
        case "ping":
            self = .ping
        case "error":
            self = .errorEvent
        default:
            self = .ping
        }
    }
}

private struct IndexCarrier: Decodable { let index: Int }

private struct MessageStart: Decodable {
    let message: MessageStartMessage
}

private struct MessageStartMessage: Decodable {
    let usage: Usage?
}

private struct Usage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

private struct ContentBlockStart: Decodable {
    let index: Int
    let contentBlock: ContentBlockStartBody

    enum CodingKeys: String, CodingKey {
        case index
        case contentBlock = "content_block"
    }
}

private enum ContentBlockStartBody: Decodable {
    case text
    case toolUse(id: String, name: String)

    enum CodingKeys: String, CodingKey {
        case type, id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            self = .toolUse(id: id, name: name)
        default:
            // Unknown block kind (e.g. server_tool_use) — treat as text so
            // the runner doesn't drop a delta.
            self = .text
        }
    }
}

private struct ContentBlockDelta: Decodable {
    let index: Int
    let delta: DeltaBody
}

private enum DeltaBody: Decodable {
    case textDelta(String)
    case inputJsonDelta(String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case partialJson = "partial_json"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text_delta":
            let text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
            self = .textDelta(text)
        case "input_json_delta":
            let partial = try container.decodeIfPresent(String.self, forKey: .partialJson) ?? ""
            self = .inputJsonDelta(partial)
        default:
            self = .textDelta("")
        }
    }
}

private struct MessageDelta: Decodable {
    let delta: MessageDeltaBody
    let usage: Usage?
}

private struct MessageDeltaBody: Decodable {
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
    }
}
