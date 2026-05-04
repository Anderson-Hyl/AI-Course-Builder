import LearningModels
import LearningUI
import SwiftUI

struct ShortAnswerBlockView: View {
    let payload: BlockPayload.ShortAnswer
    @Environment(\.theme) private var theme
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(payload.question)
                .font(.headline)
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // TODO: wire to LearningRepository.recordAttempt + EvaluationEngine.
            // expectedAnswer is intentionally NOT shown — the eval flow surfaces it
            // after submit (out of scope this pass).
            TextEditor(text: $draft)
                .font(.body)
                .foregroundStyle(theme.text.primary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.surface.input)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.border.regular, lineWidth: 1)
                        )
                )

            HStack {
                Spacer()
                Button("Check answer") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
            }
        }
        .blockCard(theme: theme)
    }
}

#Preview("ShortAnswer") {
    ShortAnswerBlockView(payload: .init(
        question: "Define referential transparency in your own words.",
        expectedAnswer: "Substitutability of expressions with their values without changing program behavior."
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
