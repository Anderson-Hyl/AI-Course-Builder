import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Library — the new top-level surface. Renders inside the persistent
/// `Shell` with a `LibrarySidebar` on the left and the course grid +
/// activity rail in the canvas. Tapping a course tile asks the parent
/// reducer to enter that course; tapping the new-course tile asks the
/// parent to present Goal Intake.
///
/// Phase 2 keeps the rendering data minimal. Course tiles show only
/// what's available from `LearningGoal` alone — text + creation order;
/// real per-course progress lands in Phase 4 once `CourseHomeFeature`
/// caches `CourseSummary` rows the tiles can read.
public struct LibraryView: View {
    @Bindable var store: StoreOf<AppFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Shell(
            breadcrumb: [BreadcrumbSegment("Library")],
            toolbar: { toolbarSlot },
            sidebar: { sidebar },
            content: { canvas }
        )
    }

    // MARK: - Topbar trailing

    private var toolbarSlot: some View {
        HStack(spacing: 8) {
            ShellButton.primary("New course", systemImage: "plus") {
                store.send(.newCourseRequested)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        LibrarySidebar(
            active: .library,
            recents: recentRows,
            userName: store.profile?.displayName ?? "Learner",
            userMeta: "learner",
            onLibraryTap: nil,
            onActivityTap: nil,
            onAllNotesTap: nil,
            onSettingsTap: { store.send(.openAPIKeySheet) },
            onCourseTap: { course in
                store.send(.courseSelected(course.id))
            }
        )
    }

    private var recentRows: [LibrarySidebar.CourseRow] {
        store.goals.prefix(5).map { goal in
            LibrarySidebar.CourseRow(
                id: goal.id,
                title: courseTitle(for: goal),
                progress: ""  // Phase 4 fills this when CourseSummary lands
            )
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHead
                if let resume = resumeTarget {
                    resumeStrip(resume)
                }
                courseGridSection
            }
            .padding(.horizontal, 40)
            .padding(.top, 32)
            .padding(.bottom, 56)
            .frame(maxWidth: 1280, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var pageHead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(theme.text.primary)
            Text(subhead)
                .font(.system(size: 14))
                .foregroundStyle(theme.text.secondary)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let phase = switch hour {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
        let name = store.profile?.displayName.split(separator: " ").first.map(String.init)
        return name.map { "\(phase), \($0)." } ?? "\(phase)."
    }

    private var subhead: String {
        if store.goals.isEmpty {
            "No courses yet — tell the AI what you want to learn and it'll draft a plan."
        } else if store.goals.count == 1 {
            "Pick up where you left off, or start something new."
        } else {
            "\(store.goals.count) courses in flight. Pick one up, or start something new."
        }
    }

    /// Most-recent goal is the resume target. When Phase 4 caches
    /// `CourseSummary.lastSession`, this strip will deep-link straight to
    /// that session. For now it just enters the course's Home / Program
    /// Map flow.
    private var resumeTarget: LearningGoal? {
        store.goals.last
    }

    private func resumeStrip(_ goal: LearningGoal) -> some View {
        Button(action: { store.send(.courseSelected(goal.id)) }) {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                    Text(courseGlyph(for: goal))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Resume where you left off")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(courseTitle(for: goal))
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                    Text("Open the course to continue")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Continue")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(theme.surface.sidebar)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(.white, in: Capsule())
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [theme.surface.sidebar, theme.surface.sidebarActive],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var courseGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your courses")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                Spacer(minLength: 8)
                Text(courseCountLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.tertiary)
            }
            grid
        }
    }

    private var courseCountLabel: String {
        let count = store.goals.count
        return count == 1 ? "1 course" : "\(count) courses"
    }

    /// 4-column grid (3 + NewCourseTile in the React design). Each
    /// `LearningGoal` becomes a `CourseTile`; the trailing
    /// `NewCourseTile` always lives in the last cell.
    private var grid: some View {
        let columns: [GridItem] = Array(
            repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
            count: 4
        )
        let tones: [CourseTile.Tone] = [.navy, .warm, .teal, .accent]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(store.goals.enumerated()), id: \.element.id) { index, goal in
                CourseTile(
                    glyph: courseGlyph(for: goal),
                    title: courseTitle(for: goal),
                    stageLine: "",
                    eta: "",
                    progress: nil,
                    tone: tones[index % tones.count],
                    isActive: goal.id == resumeTarget?.id,
                    action: { store.send(.courseSelected(goal.id)) }
                )
            }
            NewCourseTile {
                store.send(.newCourseRequested)
            }
        }
    }

    // MARK: - Course title / glyph helpers

    private func courseTitle(for goal: LearningGoal) -> String {
        let raw = goal.normalizedTopic ?? goal.text
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 60 { return trimmed }
        return String(trimmed.prefix(57)) + "…"
    }

    private func courseGlyph(for goal: LearningGoal) -> String {
        let source = goal.normalizedTopic ?? goal.text
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first {
            return String(first).uppercased()
        }
        return "•"
    }
}
