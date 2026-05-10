import SwiftUI

/// Top of the persistent shell. Brand on the left, breadcrumb beside it,
/// caller-supplied trailing slot on the right (Resume button, mode toggles,
/// streak chip), and a small avatar disc on the far right when not in
/// focus mode.
///
/// Layout mirrors the `.topbar` element in
/// `design/App Structure _standalone_.html`: 56pt tall normally, 48pt in
/// focus mode (where the avatar collapses too so the lesson canvas reads
/// distraction-free).
struct Topbar<Toolbar: View>: View {
    let breadcrumb: [BreadcrumbSegment]
    let focus: Bool
    let userInitial: String
    @ViewBuilder let toolbar: () -> Toolbar

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            BrandRow(focus: focus, userInitial: userInitial)
            Breadcrumb(segments: breadcrumb)
            Spacer(minLength: 8)
            toolbar()
            if !focus {
                Avatar()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: focus ? 48 : 56)
        .frame(maxWidth: .infinity)
        .background(theme.surface.page)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.subtle)
                .frame(height: 1)
        }
    }
}

// MARK: - Brand

private struct BrandRow: View {
    let focus: Bool
    let userInitial: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.surface.sidebar)
                Text(userInitial)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)

            if !focus {
                Text("Course Builder")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
            } else {
                Text("Course Builder")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Avatar

private struct Avatar: View {
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.87, green: 0.91, blue: 0.96),
                        Color(.sRGB, red: 0.71, green: 0.78, blue: 0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 28, height: 28)
    }
}

// MARK: - Streak chip

/// Compact chip used in the Topbar trailing slot. Shows a flame glyph and
/// a day count. The Topbar itself doesn't render this — the call site
/// drops it into the `toolbar` closure where it composes with whatever
/// other actions belong on that screen.
public struct StreakChip: View {
    let days: Int

    @Environment(\.theme) private var theme

    public init(days: Int) {
        self.days = days
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.accent.warm)
            Text("\(days) day\(days == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
    }
}

// MARK: - Topbar buttons

/// Pill-shaped Topbar action. Two flavours: `.primary` is the filled
/// accent variant (the call-to-action — Resume / Start), `.secondary` is
/// the muted bordered variant for adjacent actions like Tutor and Exit.
public struct ShellButton: View {
    public enum Style { case primary, secondary }

    let title: String
    let systemImage: String?
    let style: Style
    let action: () -> Void

    @Environment(\.theme) private var theme

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    public static func primary(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> ShellButton {
        ShellButton(title, systemImage: systemImage, style: .primary, action: action)
    }

    public static func secondary(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> ShellButton {
        ShellButton(title, systemImage: systemImage, style: .secondary, action: action)
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: style == .primary ? .semibold : .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: style == .secondary ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .primary: theme.text.inverse
        case .secondary: theme.text.secondary
        }
    }

    private var background: Color {
        switch style {
        case .primary: theme.accent.primary
        case .secondary: theme.surface.cardMuted
        }
    }

    private var strokeColor: Color {
        switch style {
        case .primary: .clear
        case .secondary: theme.border.subtle
        }
    }
}
