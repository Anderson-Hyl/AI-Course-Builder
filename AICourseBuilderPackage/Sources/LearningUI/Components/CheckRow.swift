import SwiftUI

/// Bullet-style row from the design board's `.check-item`: a small
/// accent-tinted circle holding a ✓ followed by a label. Used in the
/// "We'll Generate" check grid on Goal Intake.
public struct CheckRow: View {
    let label: String

    @Environment(\.theme) private var theme

    public init(_ label: String) {
        self.label = label
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Text("✓")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.accent.primary)
                .frame(width: 18, height: 18)
                .background(theme.accent.softFill, in: Circle())
            Text(label)
                .font(theme.typography.bodySmall)
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
