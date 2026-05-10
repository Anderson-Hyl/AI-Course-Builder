/// LLM provider abstraction. Single `ChatClient` interface returning
/// `AsyncThrowingStream<ChatEvent>`; two concrete providers behind it:
///
/// - **`AnthropicChatClient`** — URLSession + SSE against the
///   `/v1/messages` endpoint. Runs on iPad and Mac (Designed for iPad).
///   The default for the shipping iPad target.
/// - **`ClaudeCodeChatClient`** — `#if os(macOS)` only. Spawns the
///   `claude` CLI via `Process` for fast dev iteration without burning
///   API credits. The CLI inherits the user's own `claude` auth (no
///   API key on this path). Incompatible with the iPad sandbox; the
///   dev convenience path on the macOS target.
///
/// Engines (Planning / Evaluation / Adaptation / Tutor) consume this
/// abstraction via `LanguageModel.defaultPlanningModel`, which picks
/// the right wire per platform. UI layers do NOT — there is no chat
/// drawer in this product. The LLM is invisible to the user except
/// through structured outputs and the tutor panel inside the Session
/// Workspace.
public enum ChatClients {}
