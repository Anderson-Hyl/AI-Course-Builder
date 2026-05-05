import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Root view. Switches between bootstrap progress, Goal Intake, and the
/// Home Dashboard. The Home Dashboard pushes Session Workspace when the
/// learner taps a session card; future Program Map / Review Vault
/// destinations plug into the same `Destination` reducer enum on
/// `AppFeature`.
public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isBootstrapping {
                bootstrapView
            } else if store.isPlanning {
                PlanningProgressView()
            } else if let error = store.planningError {
                PlanningErrorView(
                    error: error,
                    onRetry: { store.send(.retryPlanningTapped) },
                    onUseDemo: { store.send(.useDemoFallbackTapped) },
                    onOpenSettings: { store.send(.openAPIKeySheet) }
                )
            } else if store.currentGoal != nil {
                NavigationStack {
                    HomeView(
                        store: store.scope(state: \.home, action: \.home)
                    )
                    .navigationDestination(
                        item: $store.scope(
                            state: \.destination?.sessionWorkspace,
                            action: \.destination.sessionWorkspace
                        )
                    ) { workspaceStore in
                        SessionWorkspaceView(store: workspaceStore)
                    }
                }
            } else {
                GoalIntakeView(
                    store: store.scope(state: \.goalIntake, action: \.goalIntake)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $store.scope(state: \.apiKeySheet, action: \.apiKeySheet)) { sheetStore in
            APIKeySheetView(store: sheetStore)
        }
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
