import Dependencies
import DependenciesMacros
import Foundation

/// LLM provider abstraction. Engines call `chatClient.stream(...)` and
/// iterate the returned `AsyncThrowingStream<ChatEvent, Error>`. Live
/// value resolves the API key via `APIKeyStore` and dispatches by
/// `model.provider`. Test value is the `@DependencyClient`-generated
/// unimplemented stub; tests override per-call via `withDependencies`.
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
                            @Dependency(\.apiKeyStore) var keyStore
                            guard let apiKey = try keyStore.get(provider: model.provider), !apiKey.isEmpty else {
                                continuation.finish(throwing: ChatClientError.missingAPIKey(model.provider))
                                return
                            }
                            let baseURL = (try? keyStore.getBaseURL(provider: model.provider)) ?? nil
                            switch model.provider {
                            case .anthropic:
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
                @Dependency(\.apiKeyStore) var keyStore
                let key = (try? keyStore.get(provider: provider)) ?? nil
                return (key?.isEmpty == false)
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
