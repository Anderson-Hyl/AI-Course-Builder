import LearningModels

/// Attempt scoring + competency delta engine. Takes a learner attempt and
/// produces a structured result signal: correctness classification, score,
/// feedback string. Per `ARCHITECTURE.md §4.5` v1 evaluation is as
/// deterministic as possible — prefer hard checks over LLM judgment when
/// the block carries a definitive answer key.
///
/// **Currently implements**: `multiple_choice` (deterministic compare
/// against `correct_index`). `short_answer` and `code_exercise` land
/// with the first ChatClient pass — they need LLM-as-judge against
/// `expectedAnswer` / `expectedSolution` + `rubric`.
public enum EvaluationEngine {
    /// Pure function — same inputs always produce the same result. The
    /// reducer can call this directly inside an effect without further
    /// async hops because no I/O is involved. Echoes `block.explanation`
    /// as feedback so the learner sees the same "why" regardless of
    /// pick (and the explanation field stays useful pre-attempt too).
    public static func evaluateMultipleChoice(
        input: AttemptInput.MultipleChoice,
        against block: BlockPayload.MultipleChoice
    ) -> AttemptResult.MultipleChoice {
        let correct = input.selectedIndex == block.correctIndex
        return AttemptResult.MultipleChoice(
            correct: correct,
            score: correct ? 1.0 : 0.0,
            feedback: block.explanation
        )
    }
}
