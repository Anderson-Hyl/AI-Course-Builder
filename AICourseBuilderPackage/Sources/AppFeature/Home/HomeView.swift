import ComposableArchitecture
import LearningModels
import SwiftUI

/// Single-column home dashboard: goal hero → program summary card →
/// vertical sessions list. Per PRD §7 / AGENTS UI principles: calm,
/// focused, structured — no progress charts, streaks, or gamified
/// chrome until the data justifies it. Visual polish (UIComponents
/// tokens, theme thread-through) lands with the design-system pass.
public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if let goal = store.goal {
                    goalHero(goal: goal)
                }
                if let program = store.program {
                    programCard(
                        program: program,
                        stage: store.stage,
                        sprint: store.sprint
                    )
                }
                sessionsSection
                if let message = store.loadFailure {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                resetRow
            }
            .padding(40)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func goalHero(goal: LearningGoal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow("Your goal")
            Text(goal.text)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private func programCard(
        program: ProgramBlueprint,
        stage: Stage?,
        sprint: Sprint?
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("Your program")
            Text(program.summary)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let stage {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(stage.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(stage.intent)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            if let sprint {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sprint.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(sprint.focus)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            eyebrow("Sessions")
            if store.sessions.isEmpty {
                Text("No sessions yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(store.sessions.enumerated()), id: \.element.id) { index, session in
                        SessionCard(
                            index: index + 1,
                            session: session
                        ) {
                            store.send(.sessionTapped(session.id))
                        }
                    }
                }
            }
        }
    }

    private var resetRow: some View {
        Button(role: .destructive) {
            store.send(.resetTapped)
        } label: {
            Text("Reset goal")
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

private struct SessionCard: View {
    let index: Int
    let session: Session
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(session.objective)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Text("\(session.estimatedMinutes) min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(displayName(forStatus: session.status))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(statusColor(for: session.status))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(statusColor(for: session.status).opacity(0.12))
                            )
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func displayName(forStatus status: String) -> String {
        switch status {
        case Session.Status.notStarted: "Not started"
        case Session.Status.inProgress: "In progress"
        case Session.Status.completed: "Completed"
        case Session.Status.deferred: "Deferred"
        default: status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case Session.Status.completed: .green
        case Session.Status.inProgress: .accentColor
        case Session.Status.deferred: .orange
        default: .secondary
        }
    }
}
