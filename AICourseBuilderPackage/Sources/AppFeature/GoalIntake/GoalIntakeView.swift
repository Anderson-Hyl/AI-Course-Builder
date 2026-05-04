import ComposableArchitecture
import LearningModels
import SwiftUI

/// Goal Intake screen — matches the structural intent of `concept.png`
/// panel 1. Visual polish (UIComponents tokens, hero illustration,
/// gradient background) lands with the design-system pass. This pass
/// uses plain SwiftUI + system colors so the form is functional and
/// the persistence path is testable end-to-end.
public struct GoalIntakeView: View {
    @Bindable var store: StoreOf<GoalIntakeFeature>

    public init(store: StoreOf<GoalIntakeFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                topicSection
                startingLevelSection
                timeBudgetSection
                learningStyleSection
                outcomeSection
                actionRow
            }
            .padding(40)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.windowBackgroundFallback))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Let's build your")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.primary)
            Text("personalized course")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.primary)
            Text("Tell us what you want to learn and we'll generate a focused plan with practice and feedback.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var topicSection: some View {
        section(title: "What do you want to learn?") {
            TextField(
                "e.g. I want to learn Haskell",
                text: $store.goalText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(2...4)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.inputBackgroundFallback))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .font(.system(size: 17))
        }
    }

    private var startingLevelSection: some View {
        section(title: "Where are you starting from?") {
            Picker("Starting level", selection: $store.startingLevel) {
                ForEach(LearnerProfile.StartingLevel.all, id: \.self) { level in
                    Text(displayName(forLevel: level)).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var timeBudgetSection: some View {
        section(title: "Time budget") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(store.weeklyTimeBudgetHours) hours per week")
                        .font(.system(size: 17, weight: .medium))
                    Spacer()
                    Text(timeBudgetLabel(forHours: store.weeklyTimeBudgetHours))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(store.weeklyTimeBudgetHours) },
                        set: { store.weeklyTimeBudgetHours = Int($0.rounded()) }
                    ),
                    in: 1...20,
                    step: 1
                )
            }
        }
    }

    private var learningStyleSection: some View {
        section(title: "How do you like to learn?") {
            FlowLayout(spacing: 10) {
                ForEach(LearnerProfile.LearningStyle.all, id: \.self) { style in
                    LearningStyleChip(
                        label: displayName(forStyle: style),
                        isSelected: store.learningStyles.contains(style)
                    ) {
                        store.send(.learningStyleToggled(style))
                    }
                }
            }
        }
    }

    private var outcomeSection: some View {
        section(title: "Outcome (optional)") {
            TextField(
                "e.g. ship a small Haskell tool I can show off",
                text: $store.targetOutcome
            )
            .textFieldStyle(.plain)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.inputBackgroundFallback))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.previewTapped)
            } label: {
                Text("Preview Plan")
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!store.canSubmit)

            Button {
                store.send(.startLearningTapped)
            } label: {
                Text("Start Learning")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canSubmit)
        }
        .padding(.top, 12)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            content()
        }
    }

    private func displayName(forLevel level: String) -> String {
        switch level {
        case LearnerProfile.StartingLevel.beginner: "Beginner"
        case LearnerProfile.StartingLevel.intermediate: "Intermediate"
        case LearnerProfile.StartingLevel.advanced: "Advanced"
        default: level.capitalized
        }
    }

    private func displayName(forStyle style: String) -> String {
        switch style {
        case LearnerProfile.LearningStyle.handsOn: "Hands-on"
        case LearnerProfile.LearningStyle.conceptual: "Conceptual"
        case LearnerProfile.LearningStyle.visual: "Visual"
        case LearnerProfile.LearningStyle.reading: "Reading"
        default: style.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func timeBudgetLabel(forHours hours: Int) -> String {
        switch hours {
        case ...3: "Casual"
        case 4...7: "Steady"
        case 8...12: "Focused"
        default: "Intensive"
        }
    }
}

// MARK: - Chip

private struct LearningStyleChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 1.5 : 1
                    )
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout

/// Lightweight wrapping HStack — enough for chip rows. SwiftUI's
/// `Layout` protocol does the row math; we don't need a full
/// flow-with-alignment library for the bootstrap pass.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: max(0, maxRowWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Cross-platform color shim

/// Plain SwiftUI doesn't ship a single semantic color name that means
/// "system app background" on both iOS and macOS — `Color(.windowBackground)`
/// is iOS-only, `Color(NSColor.windowBackgroundColor)` is macOS-only. These
/// extensions paper over the difference for the bootstrap pass; the
/// design-system pass replaces both with `theme.colors.base` /
/// `theme.colors.input`.
extension ColorResource {}

private extension Color {
    init(_ resource: SystemColorResource) {
        switch resource {
        case .windowBackgroundFallback:
            #if os(macOS)
            self = Color(nsColor: .windowBackgroundColor)
            #else
            self = Color(uiColor: .systemGroupedBackground)
            #endif
        case .inputBackgroundFallback:
            #if os(macOS)
            self = Color(nsColor: .textBackgroundColor)
            #else
            self = Color(uiColor: .secondarySystemBackground)
            #endif
        }
    }
}

private enum SystemColorResource {
    case windowBackgroundFallback
    case inputBackgroundFallback
}
