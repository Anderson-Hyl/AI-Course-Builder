import SwiftUI

/// Small rounded-square badge used inside metric tiles, goal inputs,
/// and the graduation card. Mirrors the design board's `.badge-circle`
/// (34×34, radius 12, accent-soft fill, accent-primary text).
public struct BadgeCircle: View {
    public enum Tone: Sendable {
        case accent
        case success
        case warm
        case neutral
    }

    let text: String
    let tone: Tone

    @Environment(\.theme) private var theme

    public init(_ text: String, tone: Tone = .accent) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 34, height: 34)
            .background(background, in: RoundedRectangle(cornerRadius: theme.radius.badge))
    }

    private var foreground: Color {
        switch tone {
        case .accent: theme.accent.primary
        case .success: theme.state.success
        case .warm: theme.accent.warm
        case .neutral: theme.text.secondary
        }
    }

    private var background: Color {
        switch tone {
        case .accent: theme.accent.softFill
        case .success: theme.state.successSoft
        case .warm: theme.accent.warmSoft
        case .neutral: theme.surface.cardMuted
        }
    }
}
