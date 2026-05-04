import LearningModels
import LearningUI
import SwiftUI

/// Public entry point: takes one `SessionBlock` row and renders the
/// matching native SwiftUI view. Dispatch goes through
/// `BlockDispatch.resolve(_:)`; unknown kinds, unsupported schema
/// versions, and malformed payloads each surface a distinct
/// placeholder so failures are loud rather than silent.
///
/// Interactive blocks consume the optional `interactions` bundle —
/// today that's `multiple_choice` selection + result. Other interactive
/// kinds extend `BlockInteractions` as their attempt-capture paths land.
public struct BlockView: View {
    public let block: SessionBlock
    public let interactions: BlockInteractions

    public init(block: SessionBlock, interactions: BlockInteractions = .init()) {
        self.block = block
        self.interactions = interactions
    }

    public var body: some View {
        switch BlockDispatch.resolve(block) {
        case .renderable(let kind):
            view(for: kind)
        case .unknownKind:
            UnknownKindPlaceholder(kind: block.kind)
        case .unsupportedVersion(let payloadVersion, let supportedVersion):
            UnsupportedVersionPlaceholder(
                kind: block.kind,
                payloadVersion: payloadVersion,
                supportedVersion: supportedVersion
            )
        case .malformedPayload:
            MalformedPayloadPlaceholder(kind: block.kind)
        }
    }

    @ViewBuilder
    private func view(for kind: BlockDispatch.ResolvedKind) -> some View {
        switch kind {
        case .title(let p): TitleBlockView(payload: p)
        case .objective(let p): ObjectiveBlockView(payload: p)
        case .concept(let p): ConceptBlockView(payload: p)
        case .example(let p): ExampleBlockView(payload: p)
        case .codeExercise(let p): CodeExerciseBlockView(payload: p)
        case .multipleChoice(let p):
            MultipleChoiceBlockView(
                payload: p,
                selectedIndex: interactions.multipleChoice?.selectedIndex,
                result: interactions.multipleChoice?.result,
                onSelect: interactions.multipleChoice?.onSelect ?? { _ in }
            )
        case .shortAnswer(let p): ShortAnswerBlockView(payload: p)
        case .reflection(let p): ReflectionBlockView(payload: p)
        case .checkpoint(let p): CheckpointBlockView(payload: p)
        case .reviewCard(let p): ReviewCardBlockView(payload: p)
        }
    }
}

/// Per-kind interaction state for `BlockView`. Add a new bucket per
/// interactive block kind as it gets attempt capture wired in. Default
/// `init()` produces no interactions — non-interactive callers (Previews,
/// program-map summaries, etc.) keep the same call site they had.
public struct BlockInteractions {
    public var multipleChoice: MultipleChoiceInteraction?

    public init(multipleChoice: MultipleChoiceInteraction? = nil) {
        self.multipleChoice = multipleChoice
    }

    public struct MultipleChoiceInteraction {
        public let selectedIndex: Int?
        public let result: AttemptResult.MultipleChoice?
        public let onSelect: (Int) -> Void

        public init(
            selectedIndex: Int?,
            result: AttemptResult.MultipleChoice?,
            onSelect: @escaping (Int) -> Void
        ) {
            self.selectedIndex = selectedIndex
            self.result = result
            self.onSelect = onSelect
        }
    }
}

// MARK: - Placeholders

struct UnknownKindPlaceholder: View {
    let kind: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Unknown block kind")
                .font(.headline)
                .foregroundStyle(theme.text.primary)
            Text("This session contains a “\(kind)” block this version of the app doesn't know how to render. Update the app to view it.")
                .font(.callout)
                .foregroundStyle(theme.text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface.cardMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.border.regular, lineWidth: 1)
                )
        )
    }
}

struct UnsupportedVersionPlaceholder: View {
    let kind: String
    let payloadVersion: Int
    let supportedVersion: Int
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Update app to view this block")
                .font(.headline)
                .foregroundStyle(theme.text.primary)
            Text("Block “\(kind)” uses schema v\(payloadVersion); this app supports up to v\(supportedVersion).")
                .font(.callout)
                .foregroundStyle(theme.text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface.warmTint)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.state.warning.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct MalformedPayloadPlaceholder: View {
    let kind: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Malformed payload")
                .font(.headline)
                .foregroundStyle(theme.state.danger)
            Text("Block “\(kind)” at the current schema version failed to decode. Check fixture or DB write — silent failures here would be the worst debugging UX.")
                .font(.callout)
                .foregroundStyle(theme.text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.state.dangerSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.state.danger.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - Previews

#Preview("Unknown kind") {
    BlockView(block: Fixtures.unknownKindBlock)
        .padding()
        .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("Unsupported version") {
    BlockView(block: Fixtures.unsupportedVersionTitle)
        .padding()
        .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("Malformed payload") {
    BlockView(block: Fixtures.malformedConcept)
        .padding()
        .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}
