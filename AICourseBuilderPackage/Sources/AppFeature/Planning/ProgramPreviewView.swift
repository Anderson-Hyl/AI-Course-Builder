import LearningUI
import PlanningEngine
import SwiftUI

/// Shown after `PlanningEngine.generateOutline` completes. Renders the
/// program summary, duration estimate, and the full ordered stage list
/// with intent. The user taps "Start Learning" to confirm the outline
/// and trigger full generation, or "Refine Goal" to discard the outline
/// and edit the goal text. Pure surface — `AppFeature` owns the actions.
struct ProgramPreviewView: View {
    let outline: OutlineProposal
    let onStartLearning: () -> Void
    let onRefineGoal: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xxl) {
                header
                summaryCard
                stageList
                actionRow
            }
            .padding(.horizontal, theme.spacing.xxl)
            .padding(.vertical, theme.spacing.xxxl)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.surface.appCanvas.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Chip("Step 2 of 4")
            Text("Your program outline")
                .font(theme.typography.pageTitle)
                .foregroundStyle(theme.text.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text("This is the shape of your journey. Refine the goal if anything feels off, or start learning and we'll generate your first session.")
                .font(theme.typography.body)
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            sectionLabel("Summary")
            Text(outline.program.summary)
                .font(theme.typography.body)
                .foregroundStyle(theme.text.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: theme.spacing.sm) {
                if let weeks = outline.program.durationWeeks {
                    Chip(durationLabel(weeks: weeks))
                }
                Chip("\(outline.stages.count) stages")
                if let topic = outline.normalizedTopic, !topic.isEmpty {
                    Chip(prettyTopic(topic))
                }
            }
        }
        .padding(theme.spacing.xl)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card)
                .stroke(theme.border.regular, lineWidth: 1)
        )
    }

    private var stageList: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            sectionLabel("Stages")
            VStack(spacing: theme.spacing.sm) {
                ForEach(sortedStages, id: \.order) { stage in
                    stageCard(stage)
                }
            }
        }
    }

    private func stageCard(_ stage: BlueprintProposal.Stage) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            BadgeCircle("\(stage.order)", tone: .accent)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(stage.title)
                    .font(theme.typography.cardTitle)
                    .foregroundStyle(theme.text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(stage.intent)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(theme.spacing.lg)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card)
                .stroke(theme.border.regular, lineWidth: 1)
        )
    }

    private var actionRow: some View {
        HStack(spacing: theme.spacing.md) {
            Button(action: onRefineGoal) {
                Text("Refine Goal")
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

            Button(action: onStartLearning) {
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
        }
        .padding(.top, theme.spacing.md)
    }

    private var sortedStages: [BlueprintProposal.Stage] {
        outline.stages.sorted { $0.order < $1.order }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.label)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(theme.text.tertiary)
    }

    private func durationLabel(weeks: Int) -> String {
        weeks == 1 ? "1 week" : "\(weeks) weeks"
    }

    private func prettyTopic(_ slug: String) -> String {
        slug.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
