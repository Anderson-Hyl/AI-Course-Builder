import LearningModels
import LearningUI
import SwiftUI
import Textual

struct ConceptBlockView: View {
    let payload: BlockPayload.Concept
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(payload.heading)
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let callout = payload.callout {
                InlineText(markdown: callout, syntaxExtensions: [.math])
                    .font(.callout)
                    .foregroundStyle(theme.text.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.surface.accentTint)
                    )
            }

            StructuredText(markdown: payload.body, syntaxExtensions: [.math])
                .font(.body)
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .blockCard(theme: theme)
    }
}

#Preview("Concept") {
    ConceptBlockView(payload: .init(
        heading: "What makes a function pure?",
        body: "A function is pure when its result is determined entirely by its arguments and it produces no observable side effects.",
        callout: "A pure function depends only on its inputs."
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
