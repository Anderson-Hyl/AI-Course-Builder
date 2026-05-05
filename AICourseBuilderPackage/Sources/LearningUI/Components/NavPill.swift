import SwiftUI

/// Sidebar nav row from the design board's `.nav-pill`. Renders a small
/// rounded badge holding a glyph + a label. Active state lifts the
/// pill to a subtle inset gradient against the navy sidebar.
public struct NavPill: View {
    let glyph: String
    let label: String
    let isActive: Bool

    @Environment(\.theme) private var theme

    public init(glyph: String, label: String, isActive: Bool = false) {
        self.glyph = glyph
        self.label = label
        self.isActive = isActive
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(glyph)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(textColor)
                .frame(width: 18, height: 18)
                .background(
                    Color.white.opacity(isActive ? 0.14 : 0.08),
                    in: RoundedRectangle(cornerRadius: 7)
                )
            Text(label)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: theme.radius.pill)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.07),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.pill)
                .stroke(
                    Color.white.opacity(isActive ? 0.08 : 0.04),
                    lineWidth: 1
                )
        )
    }

    private var textColor: Color {
        isActive ? theme.text.sidebarPrimary : theme.text.sidebarSecondary
    }
}
