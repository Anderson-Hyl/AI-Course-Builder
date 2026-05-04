import LearningModels
import LearningUI
import SwiftUI
import Textual

struct MultipleChoiceBlockView: View {
    let payload: BlockPayload.MultipleChoice
    /// Persisted (or optimistic in-flight) selection — drives both the
    /// option highlight and the correctness badge. Nil means the learner
    /// hasn't picked yet for this block.
    let selectedIndex: Int?
    /// Evaluator verdict for the latest attempt. Drives the correct/
    /// incorrect badge + explanation surface.
    let result: AttemptResult.MultipleChoice?
    /// Fired on each tap. The reducer above persists the attempt and
    /// optimistically updates `selectedIndex` + `result` so the UI
    /// reflects the choice on the same frame.
    let onSelect: (Int) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineText(markdown: payload.question, syntaxExtensions: [.math])
                .font(.headline)
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(Array(payload.options.enumerated()), id: \.offset) { index, option in
                    optionRow(index: index, option: option)
                }
            }

            if let result {
                HStack(spacing: 8) {
                    Image(systemName: result.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.correct ? theme.state.success : theme.state.warning)
                    Text(result.correct ? "Correct" : "Try again")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.text.primary)
                }
                if let explanation = result.feedback ?? payload.explanation {
                    InlineText(markdown: explanation, syntaxExtensions: [.math])
                        .font(.callout)
                        .foregroundStyle(theme.text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.surface.cardMuted)
                        )
                }
            }
        }
        .blockCard(theme: theme)
    }

    private func optionRow(index: Int, option: String) -> some View {
        let isSelected = selectedIndex == index
        return Button {
            onSelect(index)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .foregroundStyle(isSelected ? theme.accent.primary : theme.text.tertiary)
                InlineText(markdown: option, syntaxExtensions: [.math])
                    .font(.body)
                    .foregroundStyle(theme.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? theme.accent.softFill : theme.surface.cardMuted)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("MultipleChoice — pristine") {
    MultipleChoiceBlockView(
        payload: .init(
            question: "Which of these is a pure function?",
            options: ["putStrLn \"hi\"", "getCurrentTime", "\\x -> x * x", "readFile \"a\""],
            correctIndex: 2,
            explanation: "Only the third option is pure — it depends solely on its argument."
        ),
        selectedIndex: nil,
        result: nil,
        onSelect: { _ in }
    )
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("MultipleChoice — correct") {
    MultipleChoiceBlockView(
        payload: .init(
            question: "Which of these is a pure function?",
            options: ["putStrLn \"hi\"", "getCurrentTime", "\\x -> x * x", "readFile \"a\""],
            correctIndex: 2,
            explanation: "Only the third option is pure — it depends solely on its argument."
        ),
        selectedIndex: 2,
        result: .init(correct: true, score: 1.0, feedback: "Only the third option is pure — it depends solely on its argument."),
        onSelect: { _ in }
    )
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("MultipleChoice — incorrect") {
    MultipleChoiceBlockView(
        payload: .init(
            question: "Which of these is a pure function?",
            options: ["putStrLn \"hi\"", "getCurrentTime", "\\x -> x * x", "readFile \"a\""],
            correctIndex: 2,
            explanation: "Only the third option is pure — it depends solely on its argument."
        ),
        selectedIndex: 0,
        result: .init(correct: false, score: 0.0, feedback: "Only the third option is pure — it depends solely on its argument."),
        onSelect: { _ in }
    )
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
