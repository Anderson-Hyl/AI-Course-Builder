import LearningModels
import LearningUI
import SwiftUI
import Textual

struct ReflectionBlockView: View {
    let payload: BlockPayload.Reflection
    @Environment(\.theme) private var theme
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REFLECTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text.tertiary)
                .tracking(1.2)
            InlineText(markdown: payload.prompt, syntaxExtensions: [.math])
                .font(.body)
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $draft)
                .font(.body)
                .foregroundStyle(theme.text.primary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 110)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.surface.input)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.border.regular, lineWidth: 1)
                        )
                )
        }
        .blockCard(theme: theme)
    }
}

#Preview("Reflection") {
    ReflectionBlockView(payload: .init(
        prompt: "Where in your own code have you mixed pure and impure logic?"
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
