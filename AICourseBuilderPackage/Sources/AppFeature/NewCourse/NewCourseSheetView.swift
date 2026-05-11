import ComposableArchitecture
import LearningModels
import LearningUI
import PlanningEngine
import SwiftUI

/// "New course" modal — App Structure v2's draft-then-refine intake.
///
/// Renders as a `.sheet` overlay above the Library. The left column is a
/// 440pt prompt + knobs panel that drives `GoalIntakeFeature.State` (the
/// existing form state object); the right column is the live plan
/// preview, which reads `AppFeature.State.outlineProposal` and
/// `isPlanning` directly. Iteration loop: the user types a goal,
/// adjusts the knobs, taps **Preview plan** to fire a fast outline call
/// (~5–15s), inspects the stages on the right, then taps **Start this
/// course** to commit and trigger the full blueprint generation.
///
/// Phase 3 keeps Preview as an explicit button. Phase 3.5 swaps in a
/// debounced auto-stream so the outline regenerates as the prompt
/// changes — the right panel already understands streaming state.
public struct NewCourseSheetView: View {
    @Bindable var store: StoreOf<AppFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            theme.overlay.scrim
                .ignoresSafeArea()

            modalCard
                .frame(maxWidth: 1100, maxHeight: 720)
                .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface.appCanvas.ignoresSafeArea())
    }

    private var modalCard: some View {
        HStack(spacing: 0) {
            promptPanel
                .frame(width: 440)
                .frame(maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            theme.surface.page,
                            theme.surface.appCanvas.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(theme.border.subtle)
                        .frame(width: 1)
                }

            previewPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.surface.page)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(theme.shadow.float)
    }

    // MARK: - Left column: prompt + knobs

    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            promptHeader
            promptCopy
            promptInput
            startingLevelSection
            timeBudgetSection
            Spacer(minLength: 0)
            actionRow
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }

    private var promptHeader: some View {
        HStack {
            Text("New course")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(theme.text.tertiary)
            Spacer(minLength: 0)
            Button {
                store.send(.goalIntakeCancelled)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.text.tertiary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Discard and return to Library")
        }
    }

    private var promptCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What do you want to learn?")
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(theme.text.primary)
            Text("Describe the goal in your own words. The plan on the right updates when you tap Preview.")
                .font(.system(size: 13))
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var promptInput: some View {
        // Manual Binding into nested state: `$store.goalIntake.goalText`
        // returns a TCA `_StoreBindable_SwiftUI`, which TextEditor can't
        // consume. Dispatching `binding(.set(\.goalText, ...))` through
        // the parent action keeps the goalIntake reducer's BindableAction
        // path as the single mutation source.
        let goalBinding = Binding<String>(
            get: { store.goalIntake.goalText },
            set: { store.send(.goalIntake(.binding(.set(\.goalText, $0)))) }
        )
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: goalBinding)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96, maxHeight: 140)
                .padding(.vertical, 4)
        }
        .padding(14)
        .background(theme.surface.page)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.accent.primary, lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.accent.softFill, lineWidth: 4)
        )
    }

    private var startingLevelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            knobLabel("Starting level")
            HStack(spacing: 6) {
                ForEach(startingLevels, id: \.self) { level in
                    knobPill(
                        title: levelDisplayName(level),
                        isActive: store.goalIntake.startingLevel == level
                    ) {
                        store.send(.goalIntake(.binding(.set(\.startingLevel, level))))
                    }
                }
            }
        }
    }

    private var timeBudgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            knobLabel("Time budget")
            HStack(spacing: 6) {
                ForEach(timeBudgetOptions, id: \.0) { (hours, label) in
                    knobPill(
                        title: label,
                        isActive: store.goalIntake.weeklyTimeBudgetHours == hours
                    ) {
                        store.send(.goalIntake(.binding(.set(\.weeklyTimeBudgetHours, hours))))
                    }
                }
            }
        }
    }

    private func knobLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(theme.text.tertiary)
    }

    @ViewBuilder
    private func knobPill(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? theme.accent.primary : theme.text.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(
                    isActive ? theme.accent.softFill : theme.surface.card,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActive ? theme.accent.primary : theme.border.regular, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                store.send(.goalIntakeCancelled)
            } label: {
                Text("Discard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(theme.surface.cardMuted, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                store.send(.goalIntake(.previewTapped))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Preview plan")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(theme.accent.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(theme.accent.softFill, in: Capsule())
                .overlay(
                    Capsule().stroke(theme.accent.primary, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!store.goalIntake.canSubmit)

            Button {
                if store.outlineProposal != nil {
                    store.send(.outlineConfirmed)
                } else {
                    store.send(.goalIntake(.startLearningTapped))
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Start this course")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(theme.accent.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!store.goalIntake.canSubmit)
        }
    }

    // MARK: - Right column: live plan preview

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            previewHeader
            previewBody
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private var previewHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(headerDotColor)
                        .frame(width: 7, height: 7)
                    Text(headerEyebrow)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.text.tertiary)
                }
                if let outline = store.outlineProposal {
                    Text(outlineTitle(from: outline))
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(theme.text.primary)
                        .lineLimit(2)
                    Text(outlineSubtitle(from: outline))
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Your plan preview will appear here.")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(theme.text.primary)
                }
            }
            Spacer(minLength: 0)
            if let outline = store.outlineProposal {
                Text(outlineMetaPill(from: outline))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text.tertiary)
            }
        }
    }

    private var headerEyebrow: String {
        if store.isPlanning { return "Plan preview · streaming…" }
        if store.outlineProposal != nil { return "Plan preview · ready" }
        return "Plan preview"
    }

    private var headerDotColor: Color {
        if store.isPlanning { return theme.accent.primary }
        if store.outlineProposal != nil { return theme.state.success }
        return theme.state.locked
    }

    @ViewBuilder
    private var previewBody: some View {
        if let outline = store.outlineProposal {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(outline.stages.enumerated()), id: \.offset) { index, stage in
                        stageCard(index: index, stage: stage)
                    }
                    if store.isPlanning {
                        draftCard
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
        } else if store.isPlanning {
            streamingPlaceholder
        } else {
            emptyPlaceholder
        }
    }

    private func stageCard(index: Int, stage: BlueprintProposal.Stage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.text.secondary)
                .frame(width: 28, height: 28)
                .background(theme.surface.cardMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(stage.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if let count = sessionCount(for: stage) {
                        Text(count)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.text.tertiary)
                    }
                }
                Text(stage.intent)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border.subtle, lineWidth: 1)
        )
    }

    private var draftCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.border.strong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("More to come…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text.tertiary)
                Text("AI is still drafting the rest of the plan.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(theme.surface.cardMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(0.7)
    }

    private var streamingPlaceholder: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.surface.cardMuted)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(theme.surface.cardMuted).frame(height: 12)
                        Capsule().fill(theme.surface.cardMuted).frame(width: 220, height: 10)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(theme.surface.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.border.subtle, lineWidth: 1)
                )
            }
        }
        .padding(.top, 6)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(theme.accent.softFill)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.accent.primary)
            }
            .frame(width: 64, height: 64)
            Text("Tap Preview plan to draft an outline.")
                .font(.system(size: 14))
                .foregroundStyle(theme.text.secondary)
                .multilineTextAlignment(.center)
            Text("Outline takes 5–15 seconds. You can refine the goal and re-preview before committing.")
                .font(.system(size: 12))
                .foregroundStyle(theme.text.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var startingLevels: [String] {
        [
            LearnerProfile.StartingLevel.beginner,
            LearnerProfile.StartingLevel.intermediate,
            LearnerProfile.StartingLevel.advanced,
        ]
    }

    private func levelDisplayName(_ level: String) -> String {
        level.prefix(1).uppercased() + level.dropFirst()
    }

    /// Hours-per-week → label. Numbers mirror the existing
    /// `time-budget` cards in `GoalIntakeView`'s spec.
    private var timeBudgetOptions: [(Int, String)] {
        [(3, "30 min/day"), (5, "1 hr/day"), (12, "2+ hr/day")]
    }

    private func outlineTitle(from outline: OutlineProposal) -> String {
        let raw = outline.program.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        // The summary tends to be a single sentence; the title for the
        // preview header is the first 6–8 words.
        let words = raw.split(whereSeparator: \.isWhitespace)
        if words.count <= 8 {
            return raw
        }
        return words.prefix(8).joined(separator: " ") + "…"
    }

    private func outlineSubtitle(from outline: OutlineProposal) -> String {
        outline.program.summary
    }

    private func outlineMetaPill(from outline: OutlineProposal) -> String {
        let stageCount = outline.stages.count
        if let weeks = outline.program.durationWeeks {
            return "\(stageCount) stage\(stageCount == 1 ? "" : "s") · ≈ \(weeks) weeks"
        }
        return "\(stageCount) stage\(stageCount == 1 ? "" : "s")"
    }

    /// Outline proposals don't carry per-stage session counts (those
    /// land in the full blueprint). Return `nil` for now so the meta
    /// label simply elides; Phase 3.5 enriches the proposal schema.
    private func sessionCount(for stage: BlueprintProposal.Stage) -> String? { nil }
}
