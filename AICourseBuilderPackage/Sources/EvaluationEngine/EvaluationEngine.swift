/// Attempt scoring + competency delta engine. Takes a `Session` + `Attempt`
/// (+ optional expected-answer metadata) and produces a structured result
/// signal: correctness classification, feedback string, competency change.
///
/// **Placeholder this pass** — first scoring path lands with the first
/// renderable `code_exercise` / `multiple_choice` / `short_answer`
/// blocks. Per `ARCHITECTURE.md §4.5` evaluation should be as
/// deterministic as possible for v1: prefer `MultipleChoice.correctIndex`
/// matching to LLM judgment where possible, fall back to LLM-as-judge
/// for `short_answer` and `code_exercise` rubrics.
public enum EvaluationEngine {}
