import LearningUI
import SwiftUI

/// Shared monospaced code container. Dark background, white-ish text,
/// optional language tag in the top-right corner. Used by `Example`
/// and (next-pass) any other block kind that displays raw code.
struct CodeBlock: View {
    let code: String
    let language: String?
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.text.inverse)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let language {
                Text(language)
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.text.inverse.opacity(0.5))
                    .padding(8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.surface.codeBlock)
        )
    }
}
