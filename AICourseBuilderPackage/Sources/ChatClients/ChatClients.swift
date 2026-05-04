/// LLM provider abstraction. Single `ChatClient` interface returning
/// `AsyncThrowingStream<ChatEvent>`; two concrete providers behind it:
///
/// - **`AnthropicChatClient`** — URLSession + SSE against the
///   `/v1/messages` endpoint. Runs on iPad and Mac (Designed for iPad).
///   The default for the shipping iPad target.
/// - **`ClaudeCodeChatClient`** — `#if os(macOS)` only. Spawns the
///   `claude` CLI via `Process` for fast dev iteration with subagents,
///   MCP, and the full Claude Code feature surface. Incompatible with
///   the iPad sandbox; the dev convenience path on the macOS target.
///
/// **Placeholder this pass** — first concrete client lands when
/// `PlanningEngine.generateBlueprint(goal:)` is implemented. That's
/// the first end-to-end LLM path the user sees: Goal Intake → Start
/// Learning → blueprint generation → Home Dashboard with real data.
///
/// Engines (Planning / Evaluation / Adaptation / Tutor) consume this
/// abstraction. UI layers do NOT — there is no chat drawer in this
/// product. The LLM is invisible to the user except through structured
/// outputs and the tutor panel inside the Session Workspace.
public enum ChatClients {}
