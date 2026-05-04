/// Goal decomposition engine. Takes a `LearningGoal` (+ `LearnerProfile`
/// context + history) and produces a `ProgramBlueprint` plus near-term
/// stage/sprint/session expansions. Owns LLM calls via `ChatClients` —
/// engines never call the LLM directly except through the abstraction.
///
/// **Placeholder this pass** — first LLM-backed call lands once
/// `ChatClients` ships its Anthropic client. Per `ARCHITECTURE.md §4.4`
/// this is the main goal-decomposition seam; per `§5` it's step 2 in
/// the primary app loop (after `LearningGoal` creation, before
/// repository persists the blueprint).
public enum PlanningEngine {}
