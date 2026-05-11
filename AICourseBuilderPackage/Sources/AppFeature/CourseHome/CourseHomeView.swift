import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Course Home — the screen the user lands on inside a course. Renders
/// inside the persistent `Shell` with a `CourseSidebar` on the left and
/// a 2-column canvas: vertical stage timeline (the "Your path" pane that
/// replaces the old Program Map) on the left, sticky context rail with
/// Today / Streak / Review on the right.
///
/// Replaces both `HomeView` and `ProgramMapView` once `AppView`'s
/// `.course` branch routes here in Phase 4. Phase 6 deletes the old
/// views and features.
public struct CourseHomeView: View {
    @Bindable var store: StoreOf<CourseHomeFeature>
    /// Parent-supplied callbacks. Hoisted from CourseHomeFeature.delegate
    /// to AppFeature actions so the breadcrumb can route to Library and
    /// the Topbar's "Resume session" can deep-link to the today's session
    /// without CourseHomeFeature having to know about scope transitions.
    let onReturnToLibrary: () -> Void
    let onSessionTapped: (Session.ID) -> Void

    @Environment(\.theme) private var theme

    public init(
        store: StoreOf<CourseHomeFeature>,
        onReturnToLibrary: @escaping () -> Void,
        onSessionTapped: @escaping (Session.ID) -> Void
    ) {
        self.store = store
        self.onReturnToLibrary = onReturnToLibrary
        self.onSessionTapped = onSessionTapped
    }

    public var body: some View {
        Shell(
            breadcrumb: breadcrumb,
            toolbar: { toolbarSlot },
            sidebar: { sidebar },
            content: { canvas }
        )
        .onAppear {
            if let programID = store.program?.id {
                store.send(.onAppear(programID: programID))
            }
        }
    }

    // MARK: - Topbar

    private var breadcrumb: [BreadcrumbSegment] {
        let courseTitle = store.goal.map(courseTitleFromGoal) ?? "Course"
        return [
            BreadcrumbSegment("Library", action: onReturnToLibrary),
            BreadcrumbSegment(courseTitle)
        ]
    }

    private var toolbarSlot: some View {
        HStack(spacing: 8) {
            if let session = store.todaysSession {
                ShellButton.primary("Resume session", systemImage: "play.fill") {
                    onSessionTapped(session.id)
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        CourseSidebar(
            courseTitle: store.goal.map(courseTitleFromGoal) ?? "Course",
            courseMeta: courseMeta,
            stages: sidebarStages,
            active: .home,
            userName: store.profile?.displayName ?? "Learner",
            userMeta: "learner",
            onLibraryTap: onReturnToLibrary,
            onHomeTap: nil,
            onNotesTap: nil,
            onReviewTap: nil,
            onStageTap: nil  // Phase 4.5: scroll the timeline to the tapped stage
        )
    }

    private var courseMeta: String {
        let level = store.profile?.startingLevel.capitalized ?? ""
        let hours = (store.profile?.weeklyTimeBudgetHours).map { "\($0) hr/wk" } ?? ""
        return [level, hours].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var sidebarStages: [CourseSidebar.StageRow] {
        store.stages.map { stage in
            let status: CourseSidebar.StageRow.Status
            let badge: String?
            switch stage.status {
            case Stage.Status.completed:
                status = .complete
                badge = nil
            case Stage.Status.inProgress:
                status = .current
                let total = store.sessionsByStage[stage.id, default: []].count
                let done = store.sessionsByStage[stage.id, default: []].filter { $0.status == Session.Status.completed }.count
                badge = total > 0 ? "\(done)/\(total)" : nil
            default:
                status = .locked
                badge = nil
            }
            return CourseSidebar.StageRow(id: stage.id, title: stage.title, status: status, badge: badge)
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                pathColumn
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                contextRail
                    .frame(width: 360)
            }
            .padding(.horizontal, 40)
            .padding(.top, 32)
            .padding(.bottom, 56)
            .frame(maxWidth: 1280, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Left: stage timeline

    private var pathColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            pathHead
            timeline
        }
    }

    private var pathHead: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(courseHeadingEyebrow)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.text.tertiary)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(store.goal.map(courseTitleFromGoal) ?? "Course")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(theme.text.primary)
                Spacer(minLength: 0)
            }
            Text(stageMetaLine)
                .font(.system(size: 13))
                .foregroundStyle(theme.text.secondary)
        }
    }

    private var courseHeadingEyebrow: String { "Course" }

    private var stageMetaLine: String {
        let stageCount = store.stages.count
        let currentIndex = (store.stages.firstIndex(where: { $0.id == store.currentStageID }) ?? 0) + 1
        let total = store.allSessions.count
        let done = store.completedSessionsCount
        if stageCount > 0 {
            let stagePart = "Stage \(currentIndex) of \(stageCount)"
            let sessionPart = total > 0 ? " · \(done) of \(total) sessions complete" : ""
            return stagePart + sessionPart
        }
        return ""
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your path")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                Spacer(minLength: 8)
                Text(progressPercentLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.tertiary)
            }
            stageStackWithRail
        }
    }

    private var progressPercentLabel: String {
        let total = store.allSessions.count
        guard total > 0 else { return "0% complete" }
        let pct = Int((Double(store.completedSessionsCount) / Double(total) * 100).rounded())
        return "\(pct)% complete"
    }

    /// Vertical rail line + per-stage cards. Each card has a dot at
    /// `left: -22, top: 14` matching the React Stage component.
    private var stageStackWithRail: some View {
        ZStack(alignment: .topLeading) {
            railLine
                .padding(.leading, 9)
                .padding(.top, 22)
                .padding(.bottom, 22)

            VStack(spacing: 16) {
                ForEach(Array(store.stages.enumerated()), id: \.element.id) { index, stage in
                    stageCard(index: index, stage: stage)
                }
            }
            .padding(.leading, 26)
        }
    }

    private var railLine: some View {
        Rectangle()
            .fill(theme.border.regular)
            .frame(width: 2)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [theme.state.success, theme.accent.primary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: completedRailHeight)
            }
    }

    /// Rough proxy: 130pt per "level of progress" — enough to colour the
    /// rail down through the current stage so the user reads visual
    /// progress without exact pixel math.
    private var completedRailHeight: CGFloat {
        let pct = store.allSessions.isEmpty
            ? 0.0
            : Double(store.completedSessionsCount) / Double(store.allSessions.count)
        return max(40, CGFloat(pct) * 320 + 80)
    }

    @ViewBuilder
    private func stageCard(index: Int, stage: Stage) -> some View {
        let status = stageStatus(stage)
        let isCurrent = stage.id == store.currentStageID
        let dotColor: Color = switch status {
        case .completed: theme.state.success
        case .current: theme.accent.primary
        case .locked: theme.state.locked
        }
        VStack(alignment: .leading, spacing: 0) {
            stageCardBody(index: index, stage: stage, status: status, isCurrent: isCurrent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(stageCardBackground(status))
        .overlay(stageCardBorder(status))
        .opacity(status == .locked ? 0.7 : 1)
        .overlay(alignment: .topLeading) {
            Circle()
                .strokeBorder(dotColor, lineWidth: 3)
                .background(Circle().fill(theme.surface.page))
                .frame(width: 16, height: 16)
                .offset(x: -22, y: 14)
        }
    }

    @ViewBuilder
    private func stageCardBody(index: Int, stage: Stage, status: StageStatus, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STAGE \(stage.order)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(theme.text.tertiary)
                    Text(stage.title)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(theme.text.primary)
                    Text(stage.intent)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text.tertiary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 8)
                stageTrailing(stage: stage, status: status)
            }

            if isCurrent {
                stageProgressBar(stage: stage)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                stageSessionList(stage: stage)
            }
        }
    }

    @ViewBuilder
    private func stageTrailing(stage: Stage, status: StageStatus) -> some View {
        switch status {
        case .current:
            VStack(alignment: .trailing, spacing: 0) {
                Text("In progress")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent.primary)
                let total = store.sessionsByStage[stage.id, default: []].count
                if total > 0 {
                    let done = store.sessionsByStage[stage.id, default: []].filter { $0.status == Session.Status.completed }.count
                    Text("\(Int((Double(done) / Double(total) * 100).rounded()))%")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text.tertiary)
                }
            }
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.state.locked)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.state.success)
        }
    }

    @ViewBuilder
    private func stageProgressBar(stage: Stage) -> some View {
        let total = store.sessionsByStage[stage.id, default: []].count
        let done = store.sessionsByStage[stage.id, default: []].filter { $0.status == Session.Status.completed }.count
        let progress: Double = total > 0 ? Double(done) / Double(total) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.state.progressTrack)
                Capsule().fill(theme.accent.primary)
                    .frame(width: max(2, geo.size.width * progress))
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private func stageSessionList(stage: Stage) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(store.sessionsByStage[stage.id, default: []].enumerated()), id: \.element.id) { i, session in
                if i > 0 {
                    Rectangle()
                        .fill(theme.border.subtle)
                        .frame(height: 1)
                }
                sessionRow(session)
                    .padding(.vertical, 8)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        Button {
            onSessionTapped(session.id)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                sessionDot(session)
                Text(session.title)
                    .font(.system(size: 13, weight: sessionRowWeight(session)))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(sessionMetaLabel(session))
                    .font(.system(size: 11))
                    .foregroundStyle(sessionMetaColor(session))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sessionDot(_ session: Session) -> some View {
        let isDone = session.status == Session.Status.completed
        let isCurrent = session.id == store.todaysSession?.id && !isDone
        ZStack {
            Circle()
                .fill(
                    isDone ? theme.state.successSoft :
                    isCurrent ? theme.accent.softFill : theme.surface.cardMuted
                )
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.state.success)
            } else {
                Text("\(session.order)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        isCurrent ? theme.accent.primary : theme.text.tertiary
                    )
            }
        }
        .frame(width: 22, height: 22)
    }

    private func sessionRowWeight(_ session: Session) -> Font.Weight {
        session.id == store.todaysSession?.id && session.status != Session.Status.completed
            ? .semibold : .regular
    }

    private func sessionMetaLabel(_ session: Session) -> String {
        if session.id == store.todaysSession?.id && session.status != Session.Status.completed {
            return "\(session.estimatedMinutes) min · in progress"
        }
        return "\(session.estimatedMinutes) min"
    }

    private func sessionMetaColor(_ session: Session) -> Color {
        session.id == store.todaysSession?.id && session.status != Session.Status.completed
            ? theme.accent.primary : theme.text.tertiary
    }

    private func stageCardBackground(_ status: StageStatus) -> some View {
        RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
            .fill(status == .locked ? theme.surface.cardMuted : theme.surface.card)
    }

    private func stageCardBorder(_ status: StageStatus) -> some View {
        RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
            .stroke(
                status == .current ? theme.accent.primary : theme.border.subtle,
                lineWidth: 1
            )
    }

    // MARK: - Right rail

    private var contextRail: some View {
        VStack(spacing: 16) {
            todayCard
            streakCard
            reviewQueueCard
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.accent.primary)
                if let session = store.todaysSession {
                    Text(session.title)
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(theme.text.primary)
                        .lineLimit(2)
                    Text(todayMetaLine(session: session))
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text.secondary)
                } else {
                    Text("No session ready")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.text.secondary)
                    Text("Once the course is generated, the next session shows up here.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text.tertiary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [theme.accent.softFill, theme.surface.card],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Divider().background(theme.border.subtle)

            VStack(alignment: .leading, spacing: 10) {
                todayStepBar
                if let session = store.todaysSession {
                    Button {
                        onSessionTapped(session.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Continue session")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(theme.accent.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        .background(theme.surface.card)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous)
                .stroke(theme.accent.primary, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.tile + 4, style: .continuous)
                .stroke(theme.accent.softFill, lineWidth: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous))
    }

    private func todayMetaLine(session: Session) -> String {
        let stageIndex = (store.stages.firstIndex(where: { $0.id == store.currentStageID }) ?? 0) + 1
        return "Stage \(stageIndex) · Session \(session.order) · \(session.estimatedMinutes) min"
    }

    /// Phase 4 ships a static 6-step bar matching the React design's
    /// "Why · Concept · Example · Practice · Check · Reflect" rhythm.
    /// Phase 5 wires this to the real `SessionWorkspaceFeature` step
    /// state so it reflects in-session progress.
    private var todayStepBar: some View {
        let steps = ["Why", "Concept", "Example", "Practice", "Check", "Reflect"]
        return HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                VStack(spacing: 4) {
                    Capsule()
                        .fill(stepColor(at: index))
                        .frame(height: 4)
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(stepLabelColor(at: index))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func stepColor(at index: Int) -> Color {
        if index < 2 { return theme.state.success }
        if index == 2 { return theme.accent.primary }
        return theme.state.progressTrack
    }

    private func stepLabelColor(at index: Int) -> Color {
        if index < 2 { return theme.text.secondary }
        if index == 2 { return theme.accent.primary }
        return theme.text.tertiary
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Streak")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent.warm)
                    Text("7 days")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(theme.accent.softFill)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous)
                .stroke(theme.border.subtle, lineWidth: 1)
        )
    }

    private var reviewQueueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Review queue")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                Spacer(minLength: 0)
                Text("0 due")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.surface.cardMuted, in: Capsule())
            }
            Text("Spaced-repetition cards will appear here once you complete sessions.")
                .font(.system(size: 12))
                .foregroundStyle(theme.text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous)
                .stroke(theme.border.subtle, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private enum StageStatus { case completed, current, locked }

    private func stageStatus(_ stage: Stage) -> StageStatus {
        switch stage.status {
        case Stage.Status.completed: .completed
        case Stage.Status.inProgress: .current
        default: .locked
        }
    }

    private func courseTitleFromGoal(_ goal: LearningGoal) -> String {
        let raw = goal.normalizedTopic ?? goal.text
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 60 { return trimmed }
        return String(trimmed.prefix(57)) + "…"
    }
}
