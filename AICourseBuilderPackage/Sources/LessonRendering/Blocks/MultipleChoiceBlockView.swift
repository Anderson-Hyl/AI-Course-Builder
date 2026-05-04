import LearningModels
import LearningUI
import SwiftUI
import Textual

struct MultipleChoiceBlockView: View {
    let payload: BlockPayload.MultipleChoice
    @Environment(\.theme) private var theme
    @State private var selected: Int?

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

            if let selected {
                let correct = selected == payload.correctIndex
                HStack(spacing: 8) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? theme.state.success : theme.state.warning)
                    Text(correct ? "Correct" : "Try again")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.text.primary)
                }
                if let explanation = payload.explanation {
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
        let isSelected = selected == index
        return Button {
            selected = index
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

#Preview("MultipleChoice") {
    MultipleChoiceBlockView(payload: .init(
        question: "Which of these is a pure function?",
        options: ["putStrLn \"hi\"", "getCurrentTime", "\\x -> x * x", "readFile \"a\""],
        correctIndex: 2,
        explanation: "Only the third option is pure — it depends solely on its argument."
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
