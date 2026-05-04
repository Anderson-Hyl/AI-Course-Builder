import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Root view. Switches between the bootstrap progress, Goal Intake, and
/// the placeholder Home stub based on `AppFeature.State`. Lands all
/// future screens (Home Dashboard, Session Workspace, Program Map,
/// Review Vault) by adding cases to a richer route enum once they ship.
public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isBootstrapping {
                bootstrapView
            } else if let goal = store.currentGoal {
                HomeStubView(goal: goal) {
                    store.send(.resetTapped)
                }
            } else {
                GoalIntakeView(
                    store: store.scope(state: \.goalIntake, action: \.goalIntake)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            store.send(.onAppear)
        }
        .theme(.mvp)
    }

    private var bootstrapView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Preparing your workspace…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder stand-in for the future Home Dashboard. Confirms the
/// persistence round-trip works (goal text survives quit + relaunch),
/// shows the user we received their goal, and offers a Reset escape
/// hatch so the loop is fully exercisable end-to-end without an LLM.
private struct HomeStubView: View {
    let goal: LearningGoal
    let onReset: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal saved")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text(goal.text)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    nextStepRow(
                        title: "Home Dashboard",
                        detail: "Stage progress, today's session, weekly milestone — coming next pass."
                    )
                    nextStepRow(
                        title: "Session Workspace",
                        detail: "Block-rendered lessons with practice + tutor — coming after the renderer lands."
                    )
                    nextStepRow(
                        title: "Program Map",
                        detail: "Stages with locked / in-progress / completed states — after Planning ships."
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )

                Button(role: .destructive) {
                    onReset()
                } label: {
                    Text("Reset goal")
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            .padding(40)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func nextStepRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}
