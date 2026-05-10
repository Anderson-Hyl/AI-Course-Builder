import SwiftUI

/// Sidebar contents for the Library scope: Library / Activity / All notes
/// at the top, a "RECENT" section listing the user's in-flight courses,
/// then Settings + the user footer.
///
/// Phase 1 ships a static-data version. Phase 2 wires this to
/// `repository.fetchAllGoals()` and route handlers in `AppFeature`.
public struct LibrarySidebar: View {
    public enum ActiveItem { case library, activity, allNotes }

    public struct CourseRow: Identifiable, Equatable {
        public let id: UUID
        public let title: String
        public let progress: String

        public init(id: UUID = UUID(), title: String, progress: String) {
            self.id = id
            self.title = title
            self.progress = progress
        }
    }

    let active: ActiveItem
    let recents: [CourseRow]
    let userName: String
    let userMeta: String
    let onLibraryTap: (() -> Void)?
    let onActivityTap: (() -> Void)?
    let onAllNotesTap: (() -> Void)?
    let onSettingsTap: (() -> Void)?
    let onCourseTap: ((CourseRow) -> Void)?

    @Environment(\.theme) private var theme

    public init(
        active: ActiveItem = .library,
        recents: [CourseRow] = LibrarySidebar.sampleRecents,
        userName: String = "Alex Kim",
        userMeta: String = "alex@example.com",
        onLibraryTap: (() -> Void)? = nil,
        onActivityTap: (() -> Void)? = nil,
        onAllNotesTap: (() -> Void)? = nil,
        onSettingsTap: (() -> Void)? = nil,
        onCourseTap: ((CourseRow) -> Void)? = nil
    ) {
        self.active = active
        self.recents = recents
        self.userName = userName
        self.userMeta = userMeta
        self.onLibraryTap = onLibraryTap
        self.onActivityTap = onActivityTap
        self.onAllNotesTap = onAllNotesTap
        self.onSettingsTap = onSettingsTap
        self.onCourseTap = onCourseTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            NavItem(
                leading: .icon("books.vertical"),
                label: "Library",
                isActive: active == .library,
                onTap: onLibraryTap ?? {}
            )
            NavItem(
                leading: .icon("chart.bar"),
                label: "Activity",
                isActive: active == .activity,
                onTap: onActivityTap ?? {}
            )
            NavItem(
                leading: .icon("note.text"),
                label: "All notes",
                isActive: active == .allNotes,
                onTap: onAllNotesTap ?? {}
            )

            if !recents.isEmpty {
                NavSectionHeader("Recent")
                ForEach(recents) { course in
                    NavItem(
                        leading: .none,
                        label: course.title,
                        badge: course.progress,
                        onTap: onCourseTap.map { handler in { handler(course) } } ?? {}
                    )
                }
            }

            Spacer(minLength: 0)

            NavItem(
                leading: .icon("gearshape"),
                label: "Settings",
                onTap: onSettingsTap ?? {}
            )

            SidebarUserCard(name: userName, meta: userMeta)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

public extension LibrarySidebar {
    /// Demo data used by `#Preview` blocks and the Phase 1 visual check.
    /// Replaced by repository-driven data in Phase 2.
    static let sampleRecents: [CourseRow] = [
        CourseRow(title: "Haskell", progress: "5/24"),
        CourseRow(title: "Roman history", progress: "2/16"),
        CourseRow(title: "Music theory", progress: "11/14")
    ]
}

#Preview {
    LibrarySidebar(active: .library)
        .frame(width: 224, height: 720)
        .background(Color(.sRGB, red: 1, green: 0.99, blue: 0.97))
        .theme(.mvp)
}
