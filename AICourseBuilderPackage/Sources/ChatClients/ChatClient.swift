import Dependencies
import DependenciesMacros
import Foundation

/// LLM provider abstraction. Engines call `chatClient.stream(...)` and
/// iterate the returned `AsyncThrowingStream<ChatEvent, Error>`. Live
/// value resolves the API key via `APIKeyStore` (when the provider needs
/// one) and dispatches by `model.provider`. Test value is the
/// `@DependencyClient`-generated unimplemented stub; tests override
/// per-call via `withDependencies`.
@DependencyClient
public struct ChatClient: Sendable {
    public var stream: @Sendable (
        _ messages: [ChatMessage],
        _ model: LanguageModel,
        _ tools: [ToolSpec],
        _ toolChoice: ToolChoice
    ) -> AsyncThrowingStream<ChatEvent, Error> = { _, _, _, _ in
        AsyncThrowingStream { $0.finish() }
    }
    public var isAvailable: @Sendable (_ provider: ProviderID) -> Bool = { _ in false }
}

extension ChatClient: DependencyKey {
    public static var liveValue: ChatClient {
        ChatClient(
            stream: { messages, model, tools, toolChoice in
                AsyncThrowingStream { continuation in
                    let task = Task {
                        do {
                            switch model.provider {
                            case .anthropic:
                                @Dependency(\.apiKeyStore) var keyStore
                                guard let apiKey = try keyStore.get(provider: .anthropic),
                                      !apiKey.isEmpty
                                else {
                                    continuation.finish(throwing: ChatClientError.missingAPIKey(.anthropic))
                                    return
                                }
                                let baseURL = (try? keyStore.getBaseURL(provider: .anthropic)) ?? nil
                                await AnthropicChatClient.stream(
                                    messages: messages,
                                    model: model,
                                    apiKey: apiKey,
                                    baseURL: baseURL,
                                    tools: tools,
                                    toolChoice: toolChoice,
                                    continuation: continuation
                                )
                                continuation.finish()

                            case .claudeCode:
                                #if os(macOS)
                                await ClaudeCodeChatClient.stream(
                                    messages: messages,
                                    model: model,
                                    tools: tools,
                                    toolChoice: toolChoice,
                                    continuation: continuation
                                )
                                continuation.finish()
                                #else
                                continuation.finish(
                                    throwing: ChatClientError.networkError(
                                        "Claude Code CLI provider is macOS-only."
                                    )
                                )
                                #endif
                            }
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            },
            isAvailable: { provider in
                switch provider {
                case .anthropic:
                    @Dependency(\.apiKeyStore) var keyStore
                    let key = (try? keyStore.get(provider: .anthropic)) ?? nil
                    return (key?.isEmpty == false)
                case .claudeCode:
                    #if os(macOS)
                    return ClaudeCodeChatClient.detect() != nil
                    #else
                    return false
                    #endif
                }
            }
        )
    }

    public static var testValue: ChatClient { ChatClient() }
}

extension DependencyValues {
    public var chatClient: ChatClient {
        get { self[ChatClient.self] }
        set { self[ChatClient.self] = newValue }
    }
}
