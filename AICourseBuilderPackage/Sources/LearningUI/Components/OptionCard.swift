import SwiftUI

/// Selectable card with a bold title + supporting subtitle. Used by
/// the design board's `.option-card` rows (Starting Level, Time
/// Budget). Single-select pattern — the parent view tracks which
/// option is `isSelected` and routes taps to its own state.
public struct OptionCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    public init(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.text.primary)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(.horizontal, theme.spacing.regular)
            .padding(.vertical, theme.spacing.regular)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: theme.radius.card)
            .fill(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                theme.accent.softFill,
                                theme.surface.card
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(theme.surface.card)
            )
    }

    private var borderColor: Color {
        isSelected ? theme.border.accent : theme.border.regular
    }
}
