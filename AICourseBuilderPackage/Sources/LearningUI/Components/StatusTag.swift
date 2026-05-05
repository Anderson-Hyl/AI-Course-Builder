import SwiftUI

/// Pill with a leading colored dot. Matches the design board's
/// `.status-tag` and its `.success` / `.warning` / `.info` modifiers.
public struct StatusTag: View {
    public enum Tone: Sendable {
        case neutral
        case success
        case warning
        case info
        case danger
    }

    let label: String
    let tone: Tone

    @Environment(\.theme) private var theme

    public init(_ label: String, tone: Tone = .neutral) {
        self.label = label
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: theme.spacing.xs) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(theme.typography.caption)
                .foregroundStyle(theme.text.secondary)
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xs)
        .background(theme.surface.cardMuted, in: RoundedRectangle(cornerRadius: theme.radius.pill))
    }

    private var dotColor: Color {
        switch tone {
        case .neutral: theme.state.locked
        case .success: theme.state.success
        case .warning: theme.state.warning
        case .info: theme.accent.primary
        case .danger: theme.state.danger
        }
    }
}
