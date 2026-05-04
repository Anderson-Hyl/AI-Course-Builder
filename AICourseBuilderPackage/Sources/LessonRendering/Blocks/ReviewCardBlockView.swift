import LearningModels
import LearningUI
import SwiftUI

struct ReviewCardBlockView: View {
    let payload: BlockPayload.ReviewCard
    @Environment(\.theme) private var theme
    @State private var isFlipped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REVIEW")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text.tertiary)
                .tracking(1.2)
            Text(payload.front)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isFlipped {
                Text(payload.back)
                    .font(.body)
                    .foregroundStyle(theme.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.surface.successTint)
                    )
            }

            HStack {
                Spacer()
                Button(isFlipped ? "Hide answer" : "Show answer") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isFlipped.toggle()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .blockCard(theme: theme)
    }
}

#Preview("ReviewCard") {
    ReviewCardBlockView(payload: .init(
        conceptID: "11111111-1111-1111-1111-111111111111",
        front: "Define: pure function.",
        back: "A function whose output depends only on its inputs and which has no observable side effects."
    ))
    .padding()
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
