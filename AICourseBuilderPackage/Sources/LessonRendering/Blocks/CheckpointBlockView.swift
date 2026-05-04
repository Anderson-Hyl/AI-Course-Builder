import LearningModels
import LearningUI
import SwiftUI

struct CheckpointBlockView: View {
    let payload: BlockPayload.Checkpoint
    @Environment(\.theme) private var theme
    @State private var rating: Int?
    @State private var freeText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHECKPOINT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text.tertiary)
                .tracking(1.2)
            Text(payload.prompt)
                .font(.body)
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let scaleMin = payload.scaleMin,
               let scaleMax = payload.scaleMax,
               scaleMax >= scaleMin {
                ratingScale(min: scaleMin, max: scaleMax, labels: payload.scaleLabels)
            } else {
                TextEditor(text: $freeText)
                    .font(.body)
                    .foregroundStyle(theme.text.primary)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 90)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.surface.input)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.border.regular, lineWidth: 1)
                            )
                    )
            }
        }
        .blockCard(theme: theme)
    }

    private func ratingScale(min low: Int, max high: Int, labels: [String]?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(low...high, id: \.self) { value in
                let isSelected = rating == value
                Button {
                    rating = value
                } label: {
                    VStack(spacing: 6) {
                        Text("\(value)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isSelected ? theme.text.inverse : theme.text.primary)
                        if let labels, let label = labels[safe: value - low] {
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(isSelected ? theme.text.inverse.opacity(0.85) : theme.text.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? theme.accent.primary : theme.surface.cardMuted)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Checkpoint — scale") {
    CheckpointBlockView(payload: .init(
        prompt: "How confident are you with pure functions?",
        scaleMin: 1,
        scaleMax: 5,
        scaleLabels: ["Lost", "Shaky", "Okay", "Solid", "Could teach it"]
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("Checkpoint — free text") {
    CheckpointBlockView(payload: .init(prompt: "What's still unclear before we move on?"))
        .padding()
        .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
