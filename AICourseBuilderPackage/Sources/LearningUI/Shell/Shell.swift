import SwiftUI

/// One segment of a Topbar breadcrumb. The last segment in the array is
/// rendered as the current location (primary text, weight-medium); earlier
/// segments are rendered as tappable buttons when `action != nil` so the
/// breadcrumb doubles as the back-navigation affordance.
public struct BreadcrumbSegment: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let action: (() -> Void)?

    public init(_ title: String, action: (() -> Void)? = nil) {
        self.id = UUID()
        self.title = title
        self.action = action
    }

    public static func == (lhs: BreadcrumbSegment, rhs: BreadcrumbSegment) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }
}

/// Persistent app shell: a 56pt topbar (48pt in focus mode) above a
/// 224pt contextual sidebar and a flexible content canvas. Mirrors the
/// `<Shell>` primitive in `design/App Structure _standalone_.html`:
/// non-focus mode keeps the sidebar on the left, focus mode hides it so
/// the lesson can take the whole canvas.
///
/// Pass the trailing slot via the `toolbar` closure (Resume button, mode
/// toggles, exit-session). The breadcrumb and brand always live on the
/// left and never need to be re-supplied per screen.
public struct Shell<Toolbar: View, Sidebar: View, Content: View>: View {
    let breadcrumb: [BreadcrumbSegment]
    let focus: Bool
    let userInitial: String
    @ViewBuilder let toolbar: () -> Toolbar
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme

    public init(
        breadcrumb: [BreadcrumbSegment],
        focus: Bool = false,
        userInitial: String = "A",
        @ViewBuilder toolbar: @escaping () -> Toolbar,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.breadcrumb = breadcrumb
        self.focus = focus
        self.userInitial = userInitial
        self.toolbar = toolbar
        self.sidebar = sidebar
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            Topbar(
                breadcrumb: breadcrumb,
                focus: focus,
                userInitial: userInitial,
                toolbar: toolbar
            )

            if focus {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.surface.page)
            } else {
                HStack(spacing: 0) {
                    sidebar()
                        .frame(width: 224)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(theme.surface.page)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(theme.border.subtle)
                                .frame(width: 1)
                        }

                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(theme.surface.page)
                }
            }
        }
        .background(theme.surface.appCanvas.ignoresSafeArea())
    }
}

// MARK: - Convenience inits

public extension Shell where Sidebar == EmptyView {
    /// Focus-mode shell: hides the sidebar and shrinks the topbar to 48pt.
    /// Used by the Session Workspace when the lesson should take the whole
    /// canvas with the AI Tutor as a slide-over rather than a column.
    init(
        breadcrumb: [BreadcrumbSegment],
        userInitial: String = "A",
        @ViewBuilder toolbar: @escaping () -> Toolbar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            breadcrumb: breadcrumb,
            focus: true,
            userInitial: userInitial,
            toolbar: toolbar,
            sidebar: { EmptyView() },
            content: content
        )
    }
}

public extension Shell where Toolbar == EmptyView {
    /// Convenience init for shells that don't need a trailing toolbar slot.
    init(
        breadcrumb: [BreadcrumbSegment],
        focus: Bool = false,
        userInitial: String = "A",
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            breadcrumb: breadcrumb,
            focus: focus,
            userInitial: userInitial,
            toolbar: { EmptyView() },
            sidebar: sidebar,
            content: content
        )
    }
}

#Preview("Library scope") {
    Shell(
        breadcrumb: [BreadcrumbSegment("Library")],
        toolbar: {
            HStack(spacing: 8) {
                StreakChip(days: 7)
                ShellButton.primary("New course", systemImage: "plus") {}
            }
        },
        sidebar: { LibrarySidebar(active: .library) },
        content: {
            VStack(alignment: .leading, spacing: 16) {
                Text("Library canvas").font(.title2)
                Text("Course tiles render here.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
        }
    )
    .theme(.mvp)
    .frame(width: 1200, height: 760)
}

#Preview("Course scope") {
    Shell(
        breadcrumb: [
            BreadcrumbSegment("Library") {},
            BreadcrumbSegment("Haskell, end-to-end")
        ],
        toolbar: {
            HStack(spacing: 8) {
                StreakChip(days: 7)
                ShellButton.primary("Resume session", systemImage: "play.fill") {}
            }
        },
        sidebar: {
            CourseSidebar(
                courseTitle: "Haskell, end-to-end",
                courseMeta: "Beginner · 1 hr/day",
                stages: [
                    .init(title: "Functions & Types", status: .current, badge: "5/12"),
                    .init(title: "Type Classes", status: .locked, badge: nil),
                    .init(title: "Algebraic Data Types", status: .locked, badge: nil),
                    .init(title: "Monads & Effects", status: .locked, badge: nil),
                ],
                active: .home
            )
        },
        content: {
            VStack(alignment: .leading, spacing: 16) {
                Text("Course Home canvas").font(.title2)
                Text("Vertical stage path + Today rail render here.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
        }
    )
    .theme(.mvp)
    .frame(width: 1200, height: 760)
}

#Preview("Session focus mode") {
    Shell(
        breadcrumb: [
            BreadcrumbSegment("Haskell") {},
            BreadcrumbSegment("Stage 1") {},
            BreadcrumbSegment("Reading Type Signatures")
        ],
        toolbar: {
            HStack(spacing: 8) {
                Chip("14:32 elapsed")
                ShellButton.secondary("AI Tutor", systemImage: "sparkles") {}
                ShellButton.secondary("Exit session", systemImage: nil) {}
            }
        },
        content: {
            VStack(alignment: .leading, spacing: 16) {
                Text("Step 3 · Example")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Text("Decode a few signatures by hand.")
                    .font(.system(size: 32, weight: .semibold))
                Text("Lesson body fills the entire canvas in focus mode.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 32)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    )
    .theme(.mvp)
    .frame(width: 1200, height: 760)
}
