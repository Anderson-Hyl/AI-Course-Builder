import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Program Map content area — vertical list of stage cards along a
/// gradient path line. Layout follows `design/mvp-design-board.html`
/// artboard 4. Like `HomeView`, the persistent sidebar is owned by
/// `AppView`'s `SidebarShell`; this view only renders the page content.
public struct ProgramMapView: View {
    @Bindable var store: StoreOf<ProgramMapFeature>

    public init(store: StoreOf<ProgramMapFeature>) {
        self.store = store
    }

    @Environment(\.theme) private var theme

    public var body: some View {
        ScrollView {
            content
                .padding(theme.spacing.xxl)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            headline
            stageList
            graduationCard
            if let message = store.loadFailure {
                Text(message)
                    .font(theme.typography.bodySmall)
                    .foregroundStyle(theme.text.danger)
            }
        }
    }

    // MARK: - Headline

    private var headline: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text("Your Program Map")
                    .font(theme.typography.pageTitle)
                    .foregroundStyle(theme.text.primary)
                Text("A personalized path to your goal")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.tertiary)
            }
            Spacer()
            Button {
                store.send(.viewAsListTapped)
            } label: {
                Text("View as List")
                    .font(theme.typography.buttonLabel)
                    .foregroundStyle(theme.text.primary)
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.vertical, theme.spacing.md)
                    .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.pill))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.pill)
                            .stroke(theme.border.regular, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stage list

    private var stageList: some View {
        ZStack(alignment: .topLeading) {
            pathLine
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                ForEach(store.stages, id: \.id) { stage in
                    stageRow(for: stage)
                }
                if store.stages.isEmpty {
                    Text("No stages yet — generate a plan to populate the map.")
                        .font(theme.typography.bodySmall)
                        .foregroundStyle(theme.text.tertiary)
                        .padding(.leading, pathInset)
                }
            }
        }
    }

    private var pathLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        theme.state.success.opacity(0.46),
                        theme.state.locked.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2)
            .padding(.leading, 6)
            .padding(.vertical, 22)
    }

    @ViewBuilder
    private func stageRow(for stage: Stage) -> some View {
        if isExpanded(stage) {
            stageCard(stage: stage)
                .padding(.leading, pathInset)
                .overlay(alignment: .topLeading) { stageDot(stage) }
        } else {
            lockRow(stage: stage)
                .padding(.leading, pathInset)
                .overlay(alignment: .topLeading) { stageDot(stage) }
        }
    }

    private func stageDot(_ stage: Stage) -> some View {
        Circle()
            .fill(stageDotColor(for: stage))
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(theme.surface.page, lineWidth: 3)
            )
            .padding(.leading, 0)
            .padding(.top, 22)
    }

    private func stageDotColor(for stage: Stage) -> Color {
        switch stage.status {
        case Stage.Status.completed: theme.state.success
        case Stage.Status.inProgress: theme.state.success
        default: theme.state.locked
        }
    }

    private var pathInset: CGFloat { theme.spacing.xxxl }

    private func isExpanded(_ stage: Stage) -> Bool {
        stage.status == Stage.Status.inProgress || stage.id == store.currentStageID
    }

    // MARK: - Stage card (current)

    private func stageCard(stage: Stage) -> some View {
        let sessions = store.sessionsByStage[stage.id] ?? []
        let completed = sessions.filter { $0.status == Session.Status.completed }.count
        let total = sessions.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0
        return VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stage \(stage.order)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.text.tertiary)
                    Text(stage.title)
                        .font(theme.typography.cardTitle)
                        .foregroundStyle(theme.text.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stage.intent)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.text.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(stageStatusLabel(stage))
                        .font(theme.typography.caption)
                        .foregroundStyle(stageStatusTint(stage))
                    if total > 0 {
                        Text("\(completed) / \(total) sessions")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.text.secondary)
                    }
                }
            }

            if total > 0 {
                MilestoneTrack(progress: progress)
            }

            if !sessions.isEmpty {
                VStack(spacing: theme.spacing.xs) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        sessionRow(index: index, session: session)
                    }
                }
            }
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card)
                .stroke(stageBorder(stage), lineWidth: 1)
        )
        .shadow(theme.shadow.card)
    }

    private func stageStatusLabel(_ stage: Stage) -> String {
        switch stage.status {
        case Stage.Status.completed: "Completed"
        case Stage.Status.inProgress: "In Progress"
        default: "Up Next"
        }
    }

    private func stageStatusTint(_ stage: Stage) -> Color {
        switch stage.status {
        case Stage.Status.completed: theme.state.success
        case Stage.Status.inProgress: theme.state.success
        default: theme.text.secondary
        }
    }

    private func stageBorder(_ stage: Stage) -> Color {
        stage.status == Stage.Status.inProgress ? theme.border.accent : theme.border.regular
    }

    private func sessionRow(index: Int, session: Session) -> some View {
        let kind = sessionRowKind(session)
        return Button {
            store.send(.sessionTapped(session.id))
        } label: {
            HStack(spacing: theme.spacing.sm) {
                sessionRowDot(kind: kind, index: index)
                Text(session.title)
                    .font(theme.typography.bodySmall)
                    .foregroundStyle(theme.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                Text(sessionRowTrailing(session: session))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private enum SessionRowKind { case complete, current, future }

    private func sessionRowKind(_ session: Session) -> SessionRowKind {
        switch session.status {
        case Session.Status.completed: .complete
        case Session.Status.inProgress: .current
        default: .future
        }
    }

    private func sessionRowDot(kind: SessionRowKind, index: Int) -> some View {
        let label: String
        let foreground: Color
        let background: Color
        let stroke: Color
        switch kind {
        case .complete:
            label = "✓"
            foreground = theme.state.success
            background = theme.state.successSoft
            stroke = theme.state.success.opacity(0.25)
        case .current:
            label = "\(index + 1)"
            foreground = theme.accent.primary
            background = theme.accent.softFill
            stroke = theme.accent.primary.opacity(0.25)
        case .future:
            label = "\(index + 1)"
            foreground = theme.text.secondary
            background = theme.surface.cardMuted
            stroke = theme.border.subtle
        }
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 22, height: 22)
            .background(background, in: Circle())
            .overlay(Circle().stroke(stroke, lineWidth: 1))
    }

    private func sessionRowTrailing(session: Session) -> String {
        switch session.status {
        case Session.Status.inProgress: "In progress"
        default: "\(session.estimatedMinutes) min"
        }
    }

    // MARK: - Lock row

    private func lockRow(stage: Stage) -> some View {
        HStack {
            Text("Stage \(stage.order) • \(stage.title)")
                .font(theme.typography.body)
                .foregroundStyle(theme.text.secondary)
            Spacer()
            StatusTag(stage.status == Stage.Status.completed ? "Completed" : "Locked",
                      tone: stage.status == Stage.Status.completed ? .success : .neutral)
        }
        .padding(.horizontal, theme.spacing.xl)
        .padding(.vertical, theme.spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.tile))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.tile)
                .stroke(theme.border.regular, lineWidth: 1)
        )
    }

    // MARK: - Graduation card

    private var graduationCard: some View {
        HStack(spacing: theme.spacing.regular) {
            BadgeCircle("🎓", tone: .accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Graduation Goal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Text(graduationCopy)
                    .font(theme.typography.bodySmall)
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text("0 / 4 projects")
                .font(theme.typography.buttonLabel)
                .foregroundStyle(theme.text.secondary)
                .padding(.horizontal, theme.spacing.xl)
                .padding(.vertical, theme.spacing.md)
                .background(theme.surface.cardMuted, in: RoundedRectangle(cornerRadius: theme.radius.pill))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.pill)
                        .stroke(theme.border.regular, lineWidth: 1)
                )
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [theme.accent.softFill.opacity(0.6), theme.surface.card],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: theme.radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card)
                .stroke(theme.border.regular, lineWidth: 1)
        )
        .shadow(theme.shadow.card)
    }

    private var graduationCopy: String {
        if let outcome = store.profile?.targetOutcome, !outcome.isEmpty {
            return outcome
        }
        return "Build real-world projects and ship a small portfolio for your goal."
    }
}
