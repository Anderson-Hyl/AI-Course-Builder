import SwiftUI

/// Small rounded-pill chip used in the design board's hero row
/// (e.g. "Step 1 of 4", "4 screens · …"). Renders a subtle bordered
/// capsule with secondary text — meant to read as metadata, not as a
/// primary action.
public struct Chip: View {
    let label: String

    @Environment(\.theme) private var theme

    public init(_ label: String) {
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(theme.typography.bodySmall)
            .foregroundStyle(theme.text.secondary)
            .padding(.horizontal, theme.spacing.regular)
            .padding(.vertical, theme.spacing.sm)
            .background(theme.surface.card.opacity(0.84), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.border.regular, lineWidth: 1)
            )
            .shadow(theme.shadow.card)
    }
}
