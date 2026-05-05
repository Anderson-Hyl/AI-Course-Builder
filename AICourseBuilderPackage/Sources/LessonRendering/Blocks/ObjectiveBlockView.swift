import LearningModels
import LearningUI
import SwiftUI
import Textual

struct ObjectiveBlockView: View {
    let payload: BlockPayload.Objective
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OBJECTIVE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text.tertiary)
                .tracking(1.2)
            InlineText(markdown: payload.statement, syntaxExtensions: [.math])
                .font(.title3)
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Objective") {
    ObjectiveBlockView(payload: .init(statement: "Distinguish pure from impure functions and rewrite a small example into a pure form."))
        .padding()
        .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
