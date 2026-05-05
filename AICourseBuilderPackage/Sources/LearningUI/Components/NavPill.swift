import SwiftUI

/// Sidebar nav row from the design board's `.nav-pill`. Renders a small
/// rounded badge holding a glyph + a label. Active state lifts the
/// pill to a subtle inset gradient against the navy sidebar.
///
/// Pass `onTap` to make the pill interactive — typically used for
/// routes that have a screen behind them. Routes whose screens haven't
/// landed yet pass `nil` and stay inert.
public struct NavPill: View {
    let glyph: String
    let label: String
    let isActive: Bool
    let onTap: (() -> Void)?

    @Environment(\.theme) private var theme

    public init(
        glyph: String,
        label: String,
        isActive: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.glyph = glyph
        self.label = label
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
                .opacity(0.85)
        }
    }

    private var content: some View {
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
        .contentShape(Rectangle())
    }

    private var textColor: Color {
        isActive ? theme.text.sidebarPrimary : theme.text.sidebarSecondary
    }
}
