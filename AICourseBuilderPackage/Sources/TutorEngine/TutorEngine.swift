import ChatClients
import Dependencies
import DependenciesMacros
import Foundation
import LearningModels

/// Tutor engine: streams hints, reframings, encouragement, and
/// contextual help for the Session Workspace's slide-over panel. Wraps
/// `ChatClient` internally; callers (the SessionWorkspace reducer)
/// consume the returned `AsyncThrowingStream<TutorChunk, Error>`.
///
/// Per `ARCHITECTURE.md §4.7` this engine handles hints, reframings,
/// encouragement, and contextual help only. It does NOT own progress
/// state — that lives in `LearningRepository`. It does NOT modify the
/// blueprint, the session, or attempts. It only produces prose.
///
/// The tutor speaks in natural prose (not structured output), so the
/// implementation calls `chatClient.stream` with an empty tool catalog
/// and `.auto` tool choice. Each yielded `TutorChunk.text` carries the
/// CUMULATIVE response so far (mirrors `ChatEvent.text`); UI consumers
/// REPLACE the streaming bubble body per chunk, they don't append.
@DependencyClient
public struct TutorEngine: Sendable {
    /// Streams a tutor response for the latest user turn.
    ///
    /// - Parameters:
    ///   - turns: full conversation history (alternating user / tutor).
    ///     The LAST entry must be a `.user` turn — its text is the
    ///     question the tutor answers. Empty assistant turns (placeholder
    ///     for the in-flight response) are dropped before sending.
    ///   - context: snapshot of where the learner is in the session.
    public var ask: @Sendable (
        _ turns: [TutorTurn],
        _ context: TutorContext
    ) -> AsyncThrowingStream<TutorChunk, Error> = { _, _ in
        AsyncThrowingStream { $0.finish() }
    }
}

extension TutorEngine: DependencyKey {
    public static var liveValue: TutorEngine {
        TutorEngine(
            ask: { turns, context in
                AsyncThrowingStream { continuation in
                    let task = Task {
                        @Dependency(\.chatClient) var chatClient
                        @Dependency(\.apiKeyStore) var apiKeyStore

                        let model = LanguageModel.defaultTutorModel
                        if model.provider.requiresAPIKey {
                            let key = (try? apiKeyStore.get(provider: model.provider)) ?? nil
                            guard let key, !key.isEmpty else {
                                continuation.finish(throwing: TutorEngineError.missingAPIKey)
                                return
                            }
                        }

                        let messages = TutorPrompt.buildMessages(turns: turns, context: context)

                        do {
                            for try await event in chatClient.stream(
                                messages,
                                model,
                                [],
                                .auto
                            ) {
                                switch event {
                                case .text(let cumulative):
                                    continuation.yield(.text(cumulative))
                                case .done(let summary):
                                    continuation.yield(.done(stopReason: summary.stopReason))
                                }
                            }
                            continuation.finish()
                        } catch is CancellationError {
                            continuation.finish(throwing: TutorEngineError.cancelled)
                        } catch let error as ChatClientError {
                            if case .missingAPIKey = error {
                                continuation.finish(throwing: TutorEngineError.missingAPIKey)
                            } else {
                                continuation.finish(
                                    throwing: TutorEngineError.network(
                                        error.errorDescription ?? error.localizedDescription
                                    )
                                )
                            }
                        } catch {
                            continuation.finish(
                                throwing: TutorEngineError.network(error.localizedDescription)
                            )
                        }
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }
        )
    }

    public static var testValue: TutorEngine { TutorEngine() }
}

extension DependencyValues {
    public var tutorEngine: TutorEngine {
        get { self[TutorEngine.self] }
        set { self[TutorEngine.self] = newValue }
    }
}
