import ComposableArchitecture
import Foundation
import LearningModels
import LearningUI
import LessonRendering
import SwiftUI
import TutorEngine

/// Session Workspace — App Structure v2's focus mode. Renders a
/// `Shell(focus: true)` so the topbar shrinks to 48pt and the sidebar
/// disappears, giving the lesson the whole canvas. A 360pt AI Tutor
/// slide-over docks on the right when `tutorOpen` is true. The block
/// rendering inside `BlockView` is unchanged from v1 — only the chrome
/// around it.
///
/// The breadcrumb (`Course › Stage › Session`) doubles as the back
/// affordance: tapping any segment dismisses the workspace and returns
/// the user to Course Home. The "Exit session" pill on the right is a
/// redundant escape route for users who don't notice the breadcrumb.
public struct SessionWorkspaceView: View {
    @Bindable var store: StoreOf<SessionWorkspaceFeature>
    /// Parent-supplied course context. Phase 5 passes the course title +
    /// the active stage title from AppFeature's `currentGoal` and the
    /// CourseHome state. Phase 5.5 can derive these here from a deep
    /// repository lookup if the workspace ever launches in isolation
    /// (e.g. universal links).
    let courseTitle: String
    let stageTitle: String

    @Environment(\.theme) private var theme

    public init(
        store: StoreOf<SessionWorkspaceFeature>,
        courseTitle: String = "Course",
        stageTitle: String = "Stage"
    ) {
        self.store = store
        self.courseTitle = courseTitle
        self.stageTitle = stageTitle
    }

    public var body: some View {
        Shell(
            breadcrumb: breadcrumb,
            userInitial: "A",
            toolbar: { toolbarSlot },
            content: { canvas }
        )
        .overlay {
            adaptationOverlay
        }
        .task {
            store.send(.onAppear)
        }
    }

    // MARK: - Topbar

    private var breadcrumb: [BreadcrumbSegment] {
        // Breadcrumb segments and the "Exit session" pill are escape
        // routes — they bypass adaptation. Only the Done button at the
        // end of the lesson triggers `AdaptationEngine.adapt`.
        [
            BreadcrumbSegment(courseTitle) {
                store.send(.exitTapped)
            },
            BreadcrumbSegment(stageTitle) {
                store.send(.exitTapped)
            },
            BreadcrumbSegment(store.session?.title ?? "Session")
        ]
    }

    private var toolbarSlot: some View {
        HStack(spacing: 8) {
            ShellButton.secondary(store.tutorOpen ? "Hide tutor" : "AI Tutor", systemImage: "sparkles") {
                store.send(.tutorToggled)
            }
            ShellButton.secondary("Exit session") {
                store.send(.exitTapped)
            }
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        HStack(spacing: 0) {
            lessonScroller
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if store.tutorOpen {
                tutorPanel
                    .frame(width: 360)
                    .frame(maxHeight: .infinity)
                    .background(theme.surface.cardMuted)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(theme.border.subtle)
                            .frame(width: 1)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: store.tutorOpen)
    }

    private var lessonScroller: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                stepRail
                blockContent
                stepNavigation
            }
            .padding(.horizontal, store.tutorOpen ? 40 : 56)
            .padding(.vertical, 32)
            .frame(maxWidth: store.tutorOpen ? .infinity : 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: store.tutorOpen ? .topLeading : .top)
        }
    }

    // MARK: - Step rail

    /// Phase 5 ships a block-progress rail (Block N of Total) rather
    /// than the React design's six conceptual phases (Why / Concept /
    /// Example / Practice / Check / Reflect). Mapping blocks → phases
    /// requires a `BlockKind` clustering pass that lands with the
    /// SessionEngine work; this rail still reads visually correct
    /// because it dims past blocks, highlights the current, and greys
    /// out future blocks.
    @ViewBuilder
    private var stepRail: some View {
        if !store.blocks.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(store.blocks.enumerated()), id: \.element.id) { index, block in
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(stepColor(at: index))
                            .frame(height: 3)
                        Text("\(index + 1). \(stepLabel(for: block, index: index))")
                            .font(.system(size: 10, weight: stepWeight(at: index), design: .monospaced))
                            .tracking(0.4)
                            .textCase(.uppercase)
                            .foregroundStyle(stepLabelColor(at: index))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: 720)
        }
    }

    private func stepLabel(for block: SessionBlock, index: Int) -> String {
        // BlockKind round-trips snake_case; convert to a compact title
        // form for the rail label. Anything we don't recognise just
        // falls through to "Block".
        switch block.kind {
        case BlockKind.title: "Why"
        case BlockKind.objective: "Why"
        case BlockKind.concept: "Concept"
        case BlockKind.example: "Example"
        case BlockKind.codeExercise: "Practice"
        case BlockKind.multipleChoice: "Check"
        case BlockKind.shortAnswer: "Check"
        case BlockKind.reflection: "Reflect"
        case BlockKind.checkpoint: "Check"
        case BlockKind.reviewCard: "Review"
        default: "Step"
        }
    }

    private func stepColor(at index: Int) -> Color {
        if index < store.currentBlockIndex { return theme.state.success }
        if index == store.currentBlockIndex { return theme.accent.primary }
        return theme.state.progressTrack
    }

    private func stepLabelColor(at index: Int) -> Color {
        if index < store.currentBlockIndex { return theme.state.success }
        if index == store.currentBlockIndex { return theme.accent.primary }
        return theme.text.tertiary
    }

    private func stepWeight(at index: Int) -> Font.Weight {
        index == store.currentBlockIndex ? .semibold : .medium
    }

    // MARK: - Block content

    @ViewBuilder
    private var blockContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session = store.session {
                Text("Step \(store.currentBlockIndex + 1) · \(currentStepName)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.text.tertiary)
                Text(session.title)
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(theme.text.primary)
                Text(session.objective)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().background(theme.border.subtle)
            if let block = store.currentBlock {
                BlockView(
                    block: block,
                    interactions: interactions(for: block)
                )
            } else if let message = store.loadFailure {
                errorView(message)
            } else if !store.blocks.isEmpty {
                Text("Block out of range.")
                    .font(.callout)
                    .foregroundStyle(theme.text.tertiary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            }
        }
    }

    private var currentStepName: String {
        guard let block = store.currentBlock else { return "Loading" }
        return stepLabel(for: block, index: store.currentBlockIndex)
    }

    // MARK: - Step navigation (bottom)

    private var stepNavigation: some View {
        HStack(spacing: 16) {
            Button {
                store.send(.previousTapped)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(previousLabel)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(store.canGoBack ? theme.text.secondary : theme.text.tertiary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(theme.surface.cardMuted, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoBack)

            Spacer(minLength: 8)

            Text(store.blocks.isEmpty
                 ? ""
                 : "\(store.currentBlockIndex + 1) of \(store.blocks.count)")
                .font(.system(size: 11))
                .foregroundStyle(theme.text.tertiary)

            Spacer(minLength: 8)

            if store.isFinalBlock {
                Button {
                    store.send(.doneTapped)
                } label: {
                    HStack(spacing: 6) {
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(theme.accent.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.adaptation == .running)
            } else {
                Button {
                    store.send(.nextTapped)
                } label: {
                    HStack(spacing: 6) {
                        Text(nextLabel)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(theme.accent.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!store.canGoForward)
            }
        }
        .frame(maxWidth: 720)
        .padding(.top, 16)
    }

    private var previousLabel: String {
        guard store.currentBlockIndex > 0 else { return "Previous" }
        let prev = store.blocks[store.currentBlockIndex - 1]
        return stepLabel(for: prev, index: store.currentBlockIndex - 1)
    }

    private var nextLabel: String {
        guard store.currentBlockIndex + 1 < store.blocks.count else { return "Next" }
        let next = store.blocks[store.currentBlockIndex + 1]
        return "Start \(stepLabel(for: next, index: store.currentBlockIndex + 1).lowercased())"
    }

    // MARK: - Tutor slide-over

    private var tutorPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            tutorPanelHeader
            tutorScroll
            if let error = store.tutorError {
                tutorErrorBubble(error)
            }
            tutorComposer
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var tutorPanelHeader: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.accent.primary)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)
                Text("AI Tutor")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
            }
            Spacer(minLength: 0)
            Button {
                store.send(.tutorToggled)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.text.tertiary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
    }

    private var tutorScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.tutorTurns.isEmpty {
                        tutorEmptyState
                    } else {
                        ForEach(store.tutorTurns) { turn in
                            tutorTurnView(turn)
                                .id(turn.id)
                        }
                        if isWaitingForFirstChunk {
                            tutorThinkingIndicator
                                .id("tutor-thinking")
                        }
                    }
                    Color.clear.frame(height: 1).id("tutor-bottom")
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.tutorTurns.count) { _, _ in
                proxy.scrollTo("tutor-bottom", anchor: .bottom)
            }
            .onChange(of: store.tutorTurns.last?.text) { _, _ in
                proxy.scrollTo("tutor-bottom", anchor: .bottom)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var tutorEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            tutorAssistantBubble(
                "Tap a question below to ask the tutor about this lesson, or send your own."
            )
            VStack(alignment: .leading, spacing: 6) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button {
                        store.send(.tutorSuggestedTapped(prompt))
                    } label: {
                        Text(prompt)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.text.secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.surface.card, in: Capsule())
                            .overlay(
                                Capsule().stroke(theme.border.regular, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(store.tutorStreaming)
                }
            }
        }
    }

    private var suggestedPrompts: [String] {
        ["Show me another example", "Why does this work?", "Quiz me on this"]
    }

    /// True when the latest turn is a tutor turn whose text hasn't
    /// arrived yet — drives the "thinking" indicator.
    private var isWaitingForFirstChunk: Bool {
        guard store.tutorStreaming, let last = store.tutorTurns.last else { return false }
        return last.role == .tutor && last.text.isEmpty
    }

    @ViewBuilder
    private func tutorTurnView(_ turn: TutorTurn) -> some View {
        switch turn.role {
        case .user:
            tutorUserBubble(turn.text)
        case .tutor:
            if !turn.text.isEmpty {
                tutorAssistantBubble(turn.text)
            }
        }
    }

    private func tutorUserBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(.white)
            .lineSpacing(2)
            .padding(14)
            .frame(maxWidth: 280, alignment: .topTrailing)
            .multilineTextAlignment(.leading)
            .background(theme.accent.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func tutorAssistantBubble(_ text: String) -> some View {
        Text(attributedTutorBody(text))
            .font(.system(size: 12.5))
            .foregroundStyle(theme.text.secondary)
            .lineSpacing(2)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(theme.surface.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.border.subtle, lineWidth: 1)
            )
    }

    /// Best-effort Markdown rendering for streamed tutor responses. The
    /// system prompt restricts the model to light Markdown (paragraphs,
    /// inline code, short lists) so the limited inline-Markdown parser
    /// in `AttributedString(markdown:)` covers the common case. Falls
    /// back to plain text on parse failure so a partial chunk mid-fence
    /// never empties the bubble.
    private func attributedTutorBody(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return (try? AttributedString(markdown: text, options: options))
            ?? AttributedString(text)
    }

    private var tutorThinkingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Tutor is thinking…")
                .font(.system(size: 12))
                .foregroundStyle(theme.text.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border.subtle, lineWidth: 1)
        )
    }

    private func tutorErrorBubble(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.state.danger)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    store.send(.tutorRetryTapped)
                } label: {
                    Text("Retry")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.accent.primary)
                }
                .buttonStyle(.plain)
                .disabled(store.tutorStreaming)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.state.dangerSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tutorComposer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                "Ask about this lesson…",
                text: tutorDraftBinding,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .foregroundStyle(theme.text.primary)
            .lineLimit(1...4)
            .submitLabel(.send)
            .onSubmit {
                store.send(.tutorSendTapped)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.send(.tutorSendTapped)
            } label: {
                ZStack {
                    Circle().fill(canSendTutorMessage ? theme.accent.primary : theme.surface.cardMuted)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(canSendTutorMessage ? .white : theme.text.tertiary)
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!canSendTutorMessage)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.border.regular, lineWidth: 1)
        )
    }

    private var canSendTutorMessage: Bool {
        !store.tutorStreaming
            && !store.tutorComposerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tutorDraftBinding: Binding<String> {
        Binding(
            get: { store.tutorComposerDraft },
            set: { store.send(.tutorComposerChanged($0)) }
        )
    }

    // MARK: - Adaptation overlay

    /// Modal overlay shown while `AdaptationEngine.adapt` is in flight or
    /// after it failed. Blocks workspace interaction so the learner
    /// can't double-fire adaptation or wander off mid-write. The
    /// `.completed` branch is intentionally invisible — the dismiss
    /// effect fires on the same frame that state flips, so the user
    /// never sees a "completed" overlay.
    @ViewBuilder
    private var adaptationOverlay: some View {
        switch store.adaptation {
        case .running:
            ZStack {
                theme.surface.cardMuted
                    .opacity(0.85)
                    .ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Reviewing your session…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.text.primary)
                    Text("The tutor is scoring your answers and scheduling reviews. This takes a few seconds.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .padding(28)
                .background(theme.surface.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.border.subtle, lineWidth: 1)
                )
            }
            .transition(.opacity)
        case .failed(let message):
            ZStack {
                theme.surface.cardMuted
                    .opacity(0.85)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.state.danger)
                        Text("Couldn't score the session")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.text.primary)
                    }
                    Text(message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button {
                            store.send(.adaptationSkipTapped)
                        } label: {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.text.secondary)
                                .padding(.horizontal, 16)
                                .frame(height: 36)
                                .background(theme.surface.cardMuted, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                        Button {
                            store.send(.adaptationRetryTapped)
                        } label: {
                            Text("Retry")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 36)
                                .background(theme.accent.primary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .frame(maxWidth: 420)
                .background(theme.surface.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.border.subtle, lineWidth: 1)
                )
            }
            .transition(.opacity)
        case .idle, .completed:
            EmptyView()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn't load session")
                .font(.headline)
                .foregroundStyle(theme.state.danger)
            Text(message)
                .font(.callout)
                .foregroundStyle(theme.text.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.state.dangerSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension SessionWorkspaceView {
    /// Builds the per-kind interaction bundle for a block. For
    /// `multiple_choice`, decodes the latest stored attempt so the view
    /// shows the prior selection + verdict on revisit. The `onSelect`
    /// closure dispatches back into the reducer, which evaluates +
    /// persists the new attempt.
    func interactions(for block: SessionBlock) -> BlockInteractions {
        switch block.kind {
        case BlockKind.multipleChoice:
            let attempt = store.attempts[block.id]
            let input = attempt
                .flatMap { $0.inputJSON.data(using: .utf8) }
                .flatMap { try? JSONDecoder().decode(AttemptInput.MultipleChoice.self, from: $0) }
            let result = attempt
                .flatMap(\.resultJSON)
                .flatMap { $0.data(using: .utf8) }
                .flatMap { try? JSONDecoder().decode(AttemptResult.MultipleChoice.self, from: $0) }
            return BlockInteractions(
                multipleChoice: .init(
                    selectedIndex: input?.selectedIndex,
                    result: result,
                    onSelect: { index in
                        store.send(.multipleChoiceSelected(blockID: block.id, index: index))
                    }
                )
            )
        default:
            return BlockInteractions()
        }
    }
}
