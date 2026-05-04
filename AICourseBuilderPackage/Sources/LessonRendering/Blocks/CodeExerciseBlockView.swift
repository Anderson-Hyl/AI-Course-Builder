import LearningModels
import LearningUI
import SwiftUI

struct CodeExerciseBlockView: View {
    let payload: BlockPayload.CodeExercise
    @Environment(\.theme) private var theme
    @State private var draft: String = ""
    @State private var didPrime = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(payload.prompt)
                .font(.body)
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // TODO: wire to LearningRepository.recordAttempt + EvaluationEngine.
            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(theme.text.inverse)
                .scrollContentBackground(.hidden)
                .padding(14)
                .frame(minHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.surface.codeBlock)
                )

            HStack(spacing: 12) {
                Text(payload.language)
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.text.tertiary)
                Spacer()
                Button("Run") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                Button("Submit") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
            }
        }
        .onAppear {
            guard !didPrime else { return }
            draft = payload.starterCode ?? ""
            didPrime = true
        }
        .blockCard(theme: theme)
    }
}

#Preview("CodeExercise") {
    CodeExerciseBlockView(payload: .init(
        prompt: "Rewrite `greet` so it returns a `String` instead of using `putStrLn`.",
        language: "haskell",
        starterCode: "greet :: String -> IO ()\ngreet name = putStrLn (\"Hello, \" ++ name)",
        expectedSolution: "greet :: String -> String\ngreet name = \"Hello, \" ++ name"
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
