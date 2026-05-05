import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Goal Intake screen — matches `design/mvp-design-board.html` artboard
/// 1. Two-column layout: a form (goal text, level, time budget, "we'll
/// generate" check grid, action row) on the left and a decorative hero
/// illustration (orbs + layered panels) on the right. Collapses to a
/// single column on narrow widths via `ViewThatFits`.
public struct GoalIntakeView: View {
    @Bindable var store: StoreOf<GoalIntakeFeature>

    public init(store: StoreOf<GoalIntakeFeature>) {
        self.store = store
    }

    @Environment(\.theme) private var theme

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xxl) {
                header
                bodyLayout
            }
            .padding(.horizontal, theme.spacing.xxl)
            .padding(.vertical, theme.spacing.xxxl)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.surface.appCanvas.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: theme.spacing.lg) {
            BrandMark()
            Spacer()
            Chip("Step 1 of 4")
            Button {
                store.send(.gearTapped)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .frame(width: 36, height: 36)
                    .background(theme.surface.card, in: Circle())
                    .overlay(Circle().stroke(theme.border.regular, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Configure API key")
        }
    }

    // MARK: - Body layout

    @ViewBuilder
    private var bodyLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.xxxl) {
                form
                    .frame(maxWidth: 540, alignment: .topLeading)
                heroIllustration
                    .frame(maxWidth: .infinity, minHeight: 540)
            }
            VStack(alignment: .leading, spacing: theme.spacing.xxl) {
                form
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                heroIllustration
                    .frame(maxWidth: .infinity, minHeight: 360)
            }
        }
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Text("Let's build your personalized course")
                    .font(theme.typography.heroHeading)
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tell us your goal and we'll turn it into a structured learning path with focused sessions, practice, checkpoints, and review.")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            goalInputBlock
            startingLevelSection
            timeBudgetSection
            generateSection
            actionRow
        }
    }

    private var goalInputBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            sectionLabel("Learning Goal")
            HStack(spacing: theme.spacing.md) {
                BadgeCircle("λ", tone: .accent)
                TextField(
                    "I want to learn …",
                    text: $store.goalText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .font(.system(size: 15))
                .foregroundStyle(theme.text.primary)
            }
            .padding(.horizontal, theme.spacing.xl)
            .padding(.vertical, theme.spacing.lg)
            .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.input))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.input)
                    .stroke(theme.border.accent, lineWidth: 1.5)
            )
        }
        .padding(theme.spacing.xl)
        .background(
            LinearGradient(
                colors: [theme.surface.input, theme.surface.cardMuted],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: theme.radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card)
                .stroke(theme.border.regular, lineWidth: 1)
        )
    }

    private var startingLevelSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            sectionLabel("Starting Level")
            HStack(alignment: .top, spacing: theme.spacing.md) {
                ForEach(LearnerProfile.StartingLevel.all, id: \.self) { level in
                    OptionCard(
                        title: levelTitle(level),
                        subtitle: levelSubtitle(level),
                        isSelected: store.startingLevel == level
                    ) {
                        store.startingLevel = level
                    }
                }
            }
        }
    }

    private var timeBudgetSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            sectionLabel("Time Budget")
            HStack(alignment: .top, spacing: theme.spacing.md) {
                ForEach(TimeBudgetBucket.allCases, id: \.self) { bucket in
                    OptionCard(
                        title: bucket.title,
                        subtitle: bucket.subtitle,
                        isSelected: TimeBudgetBucket(weeklyHours: store.weeklyTimeBudgetHours) == bucket
                    ) {
                        store.weeklyTimeBudgetHours = bucket.weeklyHours
                    }
                }
            }
        }
    }

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            sectionLabel("We'll Generate")
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack(spacing: theme.spacing.regular) {
                    CheckRow("Structured learning path")
                    CheckRow("AI tutor hints and feedback")
                }
                HStack(spacing: theme.spacing.regular) {
                    CheckRow("Hands-on practice and projects")
                    CheckRow("Review scheduling and milestones")
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: theme.spacing.md) {
            Button {
                store.send(.previewTapped)
            } label: {
                Text("Preview Plan")
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
            .disabled(!store.canSubmit)
            .opacity(store.canSubmit ? 1 : 0.55)

            Button {
                store.send(.startLearningTapped)
            } label: {
                Text("Start Learning")
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
            .disabled(!store.canSubmit)
            .opacity(store.canSubmit ? 1 : 0.55)
        }
        .padding(.top, theme.spacing.xs)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.label)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(theme.text.tertiary)
    }

    private func levelTitle(_ level: String) -> String {
        switch level {
        case LearnerProfile.StartingLevel.beginner: "Beginner"
        case LearnerProfile.StartingLevel.intermediate: "Intermediate"
        case LearnerProfile.StartingLevel.advanced: "Advanced"
        default: level.capitalized
        }
    }

    private func levelSubtitle(_ level: String) -> String {
        switch level {
        case LearnerProfile.StartingLevel.beginner: "New to the topic"
        case LearnerProfile.StartingLevel.intermediate: "Some experience"
        case LearnerProfile.StartingLevel.advanced: "Very comfortable"
        default: ""
        }
    }

    // MARK: - Hero illustration

    private var heroIllustration: some View {
        ZStack {
            // Soft glows behind the panels
            Circle()
                .fill(theme.decorative.heroGlowWarm)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .offset(x: -100, y: -100)
            Circle()
                .fill(theme.decorative.heroGlowBlue)
                .frame(width: 380, height: 380)
                .blur(radius: 50)
                .offset(x: 110, y: 100)

            // Layered panels
            heroMainPanel
                .frame(maxWidth: 420, maxHeight: 180)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, theme.spacing.xxxl)
                .padding(.horizontal, theme.spacing.xxl)

            heroNotePanel
                .frame(maxWidth: 240)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, theme.spacing.xxl)
                .padding(.trailing, theme.spacing.xxl)

            heroMiniPanel
                .frame(width: 170, height: 96)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, theme.spacing.lg)
                .padding(.leading, theme.spacing.xl)
        }
    }

    private var heroMainPanel: some View {
        HStack(spacing: theme.spacing.xl) {
            Text("λ")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(theme.text.inverse)
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                lineCapsule(widthFraction: 0.42)
                lineCapsule(widthFraction: 0.88)
                lineCapsule(widthFraction: 0.74)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    theme.surface.sidebar,
                    theme.surface.sidebar.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: theme.radius.hero)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.hero)
                .stroke(theme.border.regular, lineWidth: 1)
        )
        .shadow(theme.shadow.float)
    }

    private var heroNotePanel: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Session Blueprint")
                .font(theme.typography.label)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(theme.text.tertiary)
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                noteLine(widthFraction: 0.64)
                noteLine(widthFraction: 0.82)
                noteLine(widthFraction: 0.54)
                noteLine(widthFraction: 0.76)
            }
        }
        .padding(theme.spacing.xl)
        .background(theme.surface.card.opacity(0.94), in: RoundedRectangle(cornerRadius: theme.radius.hero))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.hero)
                .stroke(theme.border.regular, lineWidth: 1)
        )
        .shadow(theme.shadow.float)
    }

    private var heroMiniPanel: some View {
        RoundedRectangle(cornerRadius: theme.radius.hero)
            .fill(
                LinearGradient(
                    colors: [theme.accent.warmSoft, theme.accent.warmSoft.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.hero)
                    .stroke(theme.border.regular, lineWidth: 1)
            )
            .shadow(theme.shadow.card)
    }

    private func lineCapsule(widthFraction: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: proxy.size.width * widthFraction, height: 11)
        }
        .frame(height: 11)
    }

    private func noteLine(widthFraction: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(theme.border.regular)
                .frame(width: proxy.size.width * widthFraction, height: 9)
        }
        .frame(height: 9)
    }
}

// MARK: - Time budget bucket

/// The design board's three discrete buckets ("30 min/day", "1 hr/day",
/// "2+ hrs/day"). Maps weekly hours to and from these labels so the
/// underlying `weeklyTimeBudgetHours: Int` state stays compatible with
/// `LearnerProfile` and the planning prompt.
private enum TimeBudgetBucket: String, CaseIterable {
    case lite
    case balanced
    case deep

    init(weeklyHours: Int) {
        switch weeklyHours {
        case ...4: self = .lite
        case 5...10: self = .balanced
        default: self = .deep
        }
    }

    var weeklyHours: Int {
        switch self {
        case .lite: 3
        case .balanced: 7
        case .deep: 14
        }
    }

    var title: String {
        switch self {
        case .lite: "30 min/day"
        case .balanced: "1 hr/day"
        case .deep: "2+ hrs/day"
        }
    }

    var subtitle: String {
        switch self {
        case .lite: "Fast and consistent"
        case .balanced: "Balanced pace"
        case .deep: "Deep immersion"
        }
    }
}

// MARK: - Brand mark

/// Compact brand row for screen headers — small accent-tinted badge
/// and the product name. Used in the Goal Intake header today; can
/// graduate to LearningUI once a second screen wants the same chrome.
private struct BrandMark: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Text("A")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(theme.accent.primary)
                .frame(width: 26, height: 26)
                .background(
                    LinearGradient(
                        colors: [theme.accent.softFill.opacity(0.8), theme.accent.softFill],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: theme.radius.chip)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.chip)
                        .stroke(theme.accent.primary.opacity(0.2), lineWidth: 1)
                )
            Text("AI Course Builder")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(theme.text.primary)
        }
    }
}
