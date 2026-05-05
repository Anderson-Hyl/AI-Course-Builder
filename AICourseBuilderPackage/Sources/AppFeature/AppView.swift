import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Root view. Switches between bootstrap progress, Goal Intake, and the
/// SidebarShell-wrapped main app (Home / Program Map). The shell owns
/// the sidebar so the active route can swap content without unmounting
/// the navigation chrome. SessionWorkspace pushes via NavigationStack
/// on top of whichever route is current.
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
                    SidebarShell(
                        activeRoute: store.currentRoute,
                        userName: store.profile?.displayName ?? "Learner",
                        userRole: "learner",
                        onSelectRoute: { store.send(.routeSelected($0)) }
                    ) {
                        routedContent
                    }
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

    @ViewBuilder
    private var routedContent: some View {
        switch store.currentRoute {
        case .home:
            HomeView(store: store.scope(state: \.home, action: \.home))
        case .programMap:
            ProgramMapView(store: store.scope(state: \.programMap, action: \.programMap))
        default:
            // Sessions / AI Tutor / Review / Notes don't have screens
            // yet. Their pills are inert in the sidebar so the user
            // can't actually land here, but fall back to Home anyway.
            HomeView(store: store.scope(state: \.home, action: \.home))
        }
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
