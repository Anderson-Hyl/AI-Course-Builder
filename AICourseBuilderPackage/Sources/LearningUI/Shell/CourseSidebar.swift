import SwiftUI

/// Sidebar contents for the in-Course scope: ← Library back link, course
/// header card (title + meta), Course Home / Notes / Review nav items,
/// and a "STAGES" section listing the program's stages with status dots
/// (success = current, locked = future).
///
/// Phase 1 ships a static-data version that takes its rows via
/// initializer. Phase 4 will derive the stage list from the
/// `ProgramBlueprint` loaded into `CourseHomeFeature.State`.
public struct CourseSidebar: View {
    public enum ActiveItem { case home, notes, review }

    public struct StageRow: Identifiable, Equatable {
        public enum Status { case current, locked, complete }

        public let id: UUID
        public let title: String
        public let status: Status
        public let badge: String?

        public init(id: UUID = UUID(), title: String, status: Status, badge: String? = nil) {
            self.id = id
            self.title = title
            self.status = status
            self.badge = badge
        }
    }

    let courseTitle: String
    let courseMeta: String
    let stages: [StageRow]
    let active: ActiveItem
    let userName: String
    let userMeta: String

    let onLibraryTap: (() -> Void)?
    let onHomeTap: (() -> Void)?
    let onNotesTap: (() -> Void)?
    let onReviewTap: (() -> Void)?
    let onStageTap: ((StageRow) -> Void)?

    @Environment(\.theme) private var theme

    public init(
        courseTitle: String,
        courseMeta: String,
        stages: [StageRow],
        active: ActiveItem = .home,
        userName: String = "Alex Kim",
        userMeta: String = "learner",
        onLibraryTap: (() -> Void)? = nil,
        onHomeTap: (() -> Void)? = nil,
        onNotesTap: (() -> Void)? = nil,
        onReviewTap: (() -> Void)? = nil,
        onStageTap: ((StageRow) -> Void)? = nil
    ) {
        self.courseTitle = courseTitle
        self.courseMeta = courseMeta
        self.stages = stages
        self.active = active
        self.userName = userName
        self.userMeta = userMeta
        self.onLibraryTap = onLibraryTap
        self.onHomeTap = onHomeTap
        self.onNotesTap = onNotesTap
        self.onReviewTap = onReviewTap
        self.onStageTap = onStageTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            NavItem(
                leading: .chevron,
                label: "Library",
                onTap: onLibraryTap ?? {}
            )

            courseHeader
                .padding(.bottom, 8)

            NavItem(
                leading: .icon("house"),
                label: "Course Home",
                isActive: active == .home,
                onTap: onHomeTap ?? {}
            )
            NavItem(
                leading: .icon("note.text"),
                label: "Notes",
                badge: nil,
                isActive: active == .notes,
                onTap: onNotesTap ?? {}
            )
            NavItem(
                leading: .icon("arrow.counterclockwise"),
                label: "Review",
                badge: nil,
                isActive: active == .review,
                onTap: onReviewTap ?? {}
            )

            if !stages.isEmpty {
                NavSectionHeader("Stages")
                ForEach(stages) { stage in
                    NavItem(
                        leading: .dot(dotColor(for: stage.status)),
                        label: stage.title,
                        badge: stage.badge,
                        onTap: onStageTap.map { handler in { handler(stage) } } ?? {}
                    )
                }
            }

            Spacer(minLength: 0)

            SidebarUserCard(name: userName, meta: userMeta)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var courseHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Course")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(theme.text.tertiary)
            Text(courseTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .lineLimit(2)
            Text(courseMeta)
                .font(.system(size: 11))
                .foregroundStyle(theme.text.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.subtle)
                .frame(height: 1)
                .padding(.horizontal, 4)
        }
    }

    private func dotColor(for status: StageRow.Status) -> Color {
        switch status {
        case .current: theme.state.success
        case .locked: theme.state.locked
        case .complete: theme.state.successSoft
        }
    }
}

#Preview {
    CourseSidebar(
        courseTitle: "Haskell, end-to-end",
        courseMeta: "Beginner · 1 hr/day",
        stages: [
            .init(title: "Functions & Types", status: .current, badge: "5/12"),
            .init(title: "Type Classes", status: .locked),
            .init(title: "Algebraic Data Types", status: .locked),
            .init(title: "Monads & Effects", status: .locked)
        ]
    )
    .frame(width: 224, height: 720)
    .background(Color(.sRGB, red: 1, green: 0.99, blue: 0.97))
    .theme(.mvp)
}
