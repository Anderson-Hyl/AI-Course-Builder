import LearningUI
import SwiftUI

extension View {
    /// Wraps a block view in the standard card chrome (rounded fill +
    /// subtle stroke + 20pt padding). Pulled out so per-kind views
    /// don't repeat the same chrome.
    func blockCard(theme: CourseBuilderThemePalette) -> some View {
        self
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surface.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.border.subtle, lineWidth: 1)
                    )
            )
    }
}
