import SwiftUI

/// Building blocks for the contextual sidebar. The persistent shell ships
/// two concrete sidebars (`LibrarySidebar`, `CourseSidebar`); both compose
/// from these two primitives. Style is intentionally light (page surface,
/// 13pt secondary text) — not the dark navy of the legacy `SidebarShell`,
/// because the new design treats the sidebar as a peer of the canvas, not
/// a separate dark plane.

// MARK: - Section header

public struct NavSectionHeader: View {
    let title: String

    @Environment(\.theme) private var theme

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(theme.text.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Nav item

/// One row in either sidebar. Renders as a 13pt 500-weight pill with a
/// leading icon, optional trailing badge, and active/inactive styling.
/// Pass `onTap == nil` to render an inert decorative row (used for
/// "Library" back-link in the CourseSidebar header).
public struct NavItem: View {
    public enum Leading {
        /// SF Symbol name.
        case icon(String)
        /// Small coloured dot (used for the Stages section).
        case dot(Color)
        /// No leading element — for the "← Library" back row.
        case chevron
        case none
    }

    let leading: Leading
    let label: String
    let badge: String?
    let isActive: Bool
    let onTap: (() -> Void)?

    @Environment(\.theme) private var theme

    public init(
        leading: Leading,
        label: String,
        badge: String? = nil,
        isActive: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.leading = leading
        self.label = label
        self.badge = badge
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 10) {
                leadingView
                    .frame(width: 16, alignment: .leading)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.text.tertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(theme.surface.cardMuted, in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .icon(let name):
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
        case .dot(let color):
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.leading, 4)
        case .chevron:
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.text.tertiary)
        case .none:
            EmptyView()
        }
    }

    private var textColor: Color {
        if isActive { return theme.text.primary }
        if onTap == nil { return theme.text.tertiary }
        return theme.text.secondary
    }

    private var iconColor: Color {
        isActive ? theme.text.primary : theme.text.secondary
    }

    private var background: Color {
        isActive ? theme.accent.softFill : .clear
    }
}

// MARK: - User footer card

/// Bottom-of-sidebar identity card. Avatar disc + display name + meta
/// line. Both sidebars share this footer.
public struct SidebarUserCard: View {
    let name: String
    let meta: String

    @Environment(\.theme) private var theme

    public init(name: String, meta: String) {
        self.name = name
        self.meta = meta
    }

    public var body: some View {
        HStack(spacing: 10) {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
                Text(meta)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
