import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Home Dashboard. Sidebar shell + headline + 3-column metrics row +
/// `Today's Session` × `Progress` grid + three bottom cards. Layout
/// follows `design/mvp-design-board.html` artboard 2.
public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        SidebarShell(
            activeRoute: .home,
            userName: store.profile?.displayName ?? "Learner",
            userRole: "learner"
        ) {
            ScrollView {
                content
                    .padding(theme.spacing.xxl)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    @Environment(\.theme) private var theme

    private var content: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            headline
            topMetrics
            dashboardGrid
            bottomCards
            if let message = store.loadFailure {
                Text(message)
                    .font(theme.typography.bodySmall)
                    .foregroundStyle(theme.text.danger)
            }
            resetRow
        }
    }

    // MARK: - Headline

    private var headline: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(headlineTitle)
                    .font(theme.typography.pageTitle)
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(headlineSubline)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.tertiary)
            }
            Spacer(minLength: theme.spacing.lg)
            resumeButton
        }
    }

    private var headlineTitle: String {
        if let topic = store.goal?.normalizedTopic, !topic.isEmpty {
            return "\(topic.capitalized) Journey"
        }
        return store.goal?.text ?? "Your Journey"
    }

    private var headlineSubline: String {
        guard let profile = store.profile else { return "" }
        let levelLabel = profile.startingLevel.replacingOccurrences(of: "_", with: " ").capitalized
        let hours = profile.weeklyTimeBudgetHours
        let dailyMinutes = max(15, Int(round(Double(hours) * 60.0 / 7.0)))
        let dailyLabel = dailyMinutes >= 60
            ? "\(dailyMinutes / 60) hr/day"
            : "\(dailyMinutes) min/day"
        return "\(levelLabel) • \(dailyLabel)"
    }

    @ViewBuilder
    private var resumeButton: some View {
        if let session = store.todaysSession {
            Button {
                store.send(.sessionTapped(session.id))
            } label: {
                Text("Resume Session")
                    .font(theme.typography.buttonLabel)
                    .foregroundStyle(theme.text.inverse)
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.vertical, theme.spacing.md)
                    .background(
                        LinearGradient(
                            colors: [theme.accent.primary, theme.accent.pressed],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: theme.radius.pill)
                    )
                    .shadow(theme.shadow.accentPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Top metrics

    private var topMetrics: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            MetricPill(
                label: "Current Stage",
                value: store.stage?.title ?? "—",
                caption: stageProgressCaption
            ) {
                BadgeCircle("\(stageOrder)", tone: .accent)
            }

            if let focusValue = focusMetricValue {
                MetricPill(
                    label: "This Week's Focus",
                    value: focusValue,
                    caption: focusMetricCaption
                ) {
                    BadgeCircle("◎", tone: .accent)
                }
            } else {
                MetricPill(
                    label: "This Week's Focus",
                    value: "Plan loading…",
                    caption: nil,
                    isPlaceholder: true
                )
            }

            MetricPill(
                label: "Streak",
                value: "Coming soon",
                caption: "Daily streak tracking lands with the next pass.",
                isPlaceholder: true
            )
        }
    }

    private var stageOrder: Int {
        store.stage?.order ?? 1
    }

    private var stageProgressCaption: String? {
        let total = store.sessions.count
        guard total > 0 else { return nil }
        return "\(store.completedSessionsCount) / \(total) sessions"
    }

    private var focusMetricValue: String? {
        guard let sprint = store.sprint else { return nil }
        if !sprint.focus.isEmpty { return sprint.focus }
        if !sprint.title.isEmpty { return sprint.title }
        return nil
    }

    private var focusMetricCaption: String? {
        guard let sprint = store.sprint, !sprint.title.isEmpty, !sprint.focus.isEmpty else {
            return nil
        }
        return sprint.title
    }

    // MARK: - Dashboard grid

    private var dashboardGrid: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            todaysSessionCard
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .layoutPriority(1.45)
            progressCard
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .layoutPriority(1.0)
        }
    }

    @ViewBuilder
    private var todaysSessionCard: some View {
        if let session = store.todaysSession {
            cardSurface {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("Today's Session")
                        .font(theme.typography.label)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(theme.text.tertiary)
                    HStack(alignment: .top, spacing: theme.spacing.lg) {
                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            Text(session.title)
                                .font(theme.typography.sessionTitle)
                                .foregroundStyle(theme.text.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(session.objective)
                                .font(theme.typography.bodySmall)
                                .foregroundStyle(theme.text.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        BadgeCircle("λ", tone: .accent)
                    }
                    Spacer(minLength: theme.spacing.sm)
                    HStack {
                        Text("\(session.estimatedMinutes) min · ready when you are")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.text.tertiary)
                        Spacer()
                        Button {
                            store.send(.sessionTapped(session.id))
                        } label: {
                            Text("Continue Session")
                                .font(theme.typography.buttonLabel)
                                .foregroundStyle(theme.text.inverse)
                                .padding(.horizontal, theme.spacing.xl)
                                .padding(.vertical, theme.spacing.md)
                                .background(
                                    LinearGradient(
                                        colors: [theme.accent.primary, theme.accent.pressed],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    in: RoundedRectangle(cornerRadius: theme.radius.pill)
                                )
                                .shadow(theme.shadow.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            cardSurface {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text("Today's Session")
                        .font(theme.typography.label)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(theme.text.tertiary)
                    Text("No sessions yet")
                        .font(theme.typography.sessionTitle)
                        .foregroundStyle(theme.text.primary)
                    Text("Once your program is generated, your first session will appear here.")
                        .font(theme.typography.bodySmall)
                        .foregroundStyle(theme.text.secondary)
                }
            }
        }
    }

    private var progressCard: some View {
        cardSurface {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Text("Progress")
                    .font(theme.typography.label)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(theme.text.tertiary)
                Text("Completed Sessions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Text("\(store.completedSessionsCount) / \(store.sessions.count) in the current journey")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.tertiary)
                ProgressDots(
                    total: store.sessions.count,
                    completed: store.completedSessionsCount
                )
                .padding(.top, theme.spacing.xs)
            }
        }
    }

    // MARK: - Bottom cards

    private var bottomCards: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            stubCard(
                eyebrow: "Weak Spots",
                title: "Type Classes",
                body: "Accuracy is dipping whenever abstractions stop being concrete.",
                tagLabel: "Stub",
                tagTone: .neutral
            )
            stubCard(
                eyebrow: "Recommended Review",
                title: "Algebraic Data Types",
                body: "Last reviewed 5 days ago. Good moment to bring it back before moving on.",
                tagLabel: "Stub",
                tagTone: .neutral
            )
            stubCard(
                eyebrow: "Weekly Milestone",
                title: "Complete 3 more sessions",
                body: "Finish this stage and unlock the next block on type classes and polymorphism.",
                tagLabel: "Stub",
                tagTone: .neutral,
                showMilestoneTrack: true
            )
        }
    }

    private func stubCard(
        eyebrow: String,
        title: String,
        body: String,
        tagLabel: String,
        tagTone: StatusTag.Tone,
        showMilestoneTrack: Bool = false
    ) -> some View {
        cardSurface(minHeight: 156) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Text(eyebrow)
                    .font(theme.typography.label)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(theme.text.tertiary)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Text(body)
                    .font(theme.typography.bodySmall)
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if showMilestoneTrack {
                    MilestoneTrack(progress: 0.72)
                }
                StatusTag(tagLabel, tone: tagTone)
            }
        }
    }

    // MARK: - Reset (kept until a settings surface lands)

    private var resetRow: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                store.send(.resetTapped)
            } label: {
                Text("Reset goal")
                    .font(theme.typography.buttonLabel)
                    .foregroundStyle(theme.text.danger)
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.vertical, theme.spacing.md)
                    .background(
                        theme.state.dangerSoft,
                        in: RoundedRectangle(cornerRadius: theme.radius.pill)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func cardSurface<Body: View>(
        minHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Body
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .padding(theme.spacing.xl)
            .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card)
                    .stroke(theme.border.regular, lineWidth: 1)
            )
            .shadow(theme.shadow.card)
    }
}
