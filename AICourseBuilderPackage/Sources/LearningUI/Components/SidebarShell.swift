import SwiftUI

/// The six routes the persistent sidebar advertises. `.home` and
/// `.programMap` resolve to real screens; the other four render as
/// inactive pills so the nav has the right visual weight while their
/// screens are still placeholder stubs (Sessions list, AI Tutor,
/// Review Vault, Notes).
public enum SidebarRoute: Sendable, CaseIterable, Equatable {
    case home
    case programMap
    case sessions
    case aiTutor
    case review
    case notes

    public var label: String {
        switch self {
        case .home: "Home"
        case .programMap: "Program Map"
        case .sessions: "Sessions"
        case .aiTutor: "AI Tutor"
        case .review: "Review"
        case .notes: "Notes"
        }
    }

    public var glyph: String {
        switch self {
        case .home: "⌂"
        case .programMap: "◎"
        case .sessions: "▣"
        case .aiTutor: "✦"
        case .review: "↺"
        case .notes: "✎"
        }
    }

    /// `true` for routes that have a real screen wired up. The shell
    /// forwards taps for these via `onSelectRoute`; the rest stay inert.
    public var hasScreen: Bool {
        switch self {
        case .home, .programMap: true
        default: false
        }
    }
}

/// Wraps a screen with the design board's persistent left sidebar
/// (132pt brand + nav + user card column). The content area paints
/// against `surface.page`; the page sits inside the warmer
/// `surface.appCanvas` so the sidebar reads as a separate plane.
///
/// Pass `onSelectRoute` to make the wired routes (`.hasScreen == true`)
/// tappable; the closure fires for any wired route the user picks.
/// Inactive / unwired routes stay inert regardless.
public struct SidebarShell<Content: View>: View {
    let activeRoute: SidebarRoute
    let userName: String
    let userRole: String
    let onSelectRoute: ((SidebarRoute) -> Void)?
    let content: Content

    @Environment(\.theme) private var theme

    public init(
        activeRoute: SidebarRoute,
        userName: String,
        userRole: String,
        onSelectRoute: ((SidebarRoute) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.activeRoute = activeRoute
        self.userName = userName
        self.userRole = userRole
        self.onSelectRoute = onSelectRoute
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 132)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.surface.page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface.appCanvas.ignoresSafeArea())
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: theme.spacing.regular) {
            brand
                .padding(.bottom, theme.spacing.sm)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                ForEach(SidebarRoute.allCases, id: \.self) { route in
                    NavPill(
                        glyph: route.glyph,
                        label: route.label,
                        isActive: route == activeRoute,
                        onTap: tapHandler(for: route)
                    )
                }
            }
            Spacer(minLength: 0)
            userCard
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.xxl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [
                    theme.surface.sidebar,
                    theme.surface.sidebar.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func tapHandler(for route: SidebarRoute) -> (() -> Void)? {
        guard let onSelectRoute, route.hasScreen, route != activeRoute else {
            return nil
        }
        return { onSelectRoute(route) }
    }

    private var brand: some View {
        HStack(spacing: theme.spacing.sm) {
            Text("A")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(theme.text.sidebarPrimary)
                .frame(width: 26, height: 26)
                .background(
                    Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: theme.radius.chip)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.chip)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            Text("Course Builder")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.text.sidebarPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var userCard: some View {
        HStack(spacing: theme.spacing.sm) {
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
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text.sidebarPrimary)
                    .lineLimit(1)
                Text(userRole)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.sidebarSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.md)
        .background(
            Color.white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: theme.radius.tile)
        )
    }
}
