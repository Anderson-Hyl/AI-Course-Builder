import LearningModels
import LearningUI
import SwiftUI

struct TitleBlockView: View {
    let payload: BlockPayload.Title
    @Environment(\.theme) private var theme

    var body: some View {
        Text(payload.text)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(theme.text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Title") {
    TitleBlockView(payload: .init(text: "Lesson 3 · Pure Functions"))
        .padding()
        .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("Title — dark") {
    TitleBlockView(payload: .init(text: "Lesson 3 · Pure Functions"))
        .padding()
        .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
        .preferredColorScheme(.dark)
}
