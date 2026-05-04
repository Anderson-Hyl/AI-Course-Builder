import EvaluationEngine
import LearningModels
import Testing

@Suite("EvaluationEngine multiple-choice")
struct EvaluationEngineMultipleChoiceTests {

    @Test func correctSelectionScoresOne() {
        let block = BlockPayload.MultipleChoice(
            question: "q",
            options: ["a", "b", "c"],
            correctIndex: 1,
            explanation: "because"
        )
        let result = EvaluationEngine.evaluateMultipleChoice(
            input: .init(selectedIndex: 1),
            against: block
        )
        #expect(result.correct)
        #expect(result.score == 1.0)
        #expect(result.feedback == "because")
    }

    @Test func incorrectSelectionScoresZero() {
        let block = BlockPayload.MultipleChoice(
            question: "q",
            options: ["a", "b", "c"],
            correctIndex: 0,
            explanation: nil
        )
        let result = EvaluationEngine.evaluateMultipleChoice(
            input: .init(selectedIndex: 2),
            against: block
        )
        #expect(!result.correct)
        #expect(result.score == 0.0)
        #expect(result.feedback == nil)
    }

    @Test func feedbackEchoesExplanationRegardlessOfCorrectness() {
        let block = BlockPayload.MultipleChoice(
            question: "q",
            options: ["a", "b"],
            correctIndex: 0,
            explanation: "always shown"
        )
        let correct = EvaluationEngine.evaluateMultipleChoice(input: .init(selectedIndex: 0), against: block)
        let wrong = EvaluationEngine.evaluateMultipleChoice(input: .init(selectedIndex: 1), against: block)
        #expect(correct.feedback == "always shown")
        #expect(wrong.feedback == "always shown")
    }
}
