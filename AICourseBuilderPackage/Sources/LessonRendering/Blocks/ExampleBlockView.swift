import LearningModels
import LearningUI
import SwiftUI

struct ExampleBlockView: View {
    let payload: BlockPayload.Example
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading = payload.heading {
                Text(heading)
                    .font(.headline)
                    .foregroundStyle(theme.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let prose = payload.prose {
                Text(prose)
                    .font(.body)
                    .foregroundStyle(theme.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let code = payload.code {
                CodeBlock(code: code, language: payload.language)
            }
        }
        .blockCard(theme: theme)
    }
}

#Preview("Example") {
    ExampleBlockView(payload: .init(
        heading: "Pure vs impure",
        prose: "The first version writes to standard output — that's a side effect.",
        code: "greeting :: String -> String\ngreeting name = \"Hello, \" ++ name",
        language: "haskell"
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
