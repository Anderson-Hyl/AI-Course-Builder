import ComposableArchitecture
import Foundation
import LearningModels
import LessonRendering
import SwiftUI

/// Renders one `BlockView` at a time within a single ScrollView, with a
/// thin chrome (session title + objective above, Back / (Next or Done)
/// below). The center column is constrained to 720pt to match Goal Intake
/// and Home Dashboard so the visual rhythm stays consistent across screens.
public struct SessionWorkspaceView: View {
    @Bindable var store: StoreOf<SessionWorkspaceFeature>

    public init(store: StoreOf<SessionWorkspaceFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
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
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    }
                }
                .padding(40)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(store.session?.title ?? "Session")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            store.send(.onAppear)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session = store.session {
                progressIndicator
                Text(session.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(session.objective)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            Text(progressLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer(minLength: 0)
        }
    }

    private var progressLabel: String {
        guard !store.blocks.isEmpty else { return "" }
        return "Block \(store.currentBlockIndex + 1) of \(store.blocks.count)"
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn't load session")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.previousTapped)
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .disabled(!store.canGoBack)

            Spacer()

            if store.isFinalBlock {
                Button {
                    store.send(.doneTapped)
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    store.send(.nextTapped)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(NextButtonLabelStyle())
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canGoForward)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.bar)
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

private struct NextButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
