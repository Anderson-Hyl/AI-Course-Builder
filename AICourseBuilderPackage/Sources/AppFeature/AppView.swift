import ComposableArchitecture
import LearningModels
import LearningUI
import SwiftUI

/// Root view. Dispatches by `AppFeature.Scope`:
/// `.library` → `LibraryView` (the new home screen, App Structure v2).
/// `.newCourse` → Goal Intake form wrapped in a minimal back-out chrome.
/// `.course(_)` → legacy `SidebarShell` hosting Home / Program Map / the
///                pushed SessionWorkspace. Phase 4 collapses this branch
///                onto the new `Shell` + `CourseSidebar` and a single
///                `CourseHomeView`.
///
/// The transient surfaces (bootstrap spinner, planning progress, planning
/// error, outline preview) still gate ahead of the scope switch because
/// they're orthogonal to whichever scope the user is in.
public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isBootstrapping {
                bootstrapView
            } else if store.isPlanning, store.appScope != .newCourse {
                // `.newCourse` handles the streaming outline inline in
                // the right panel of the modal. For every other scope
                // (full blueprint generation, retries from .course),
                // take over the whole screen so progress is unmistakable.
                PlanningProgressView(mode: store.pendingPlanningMode)
            } else if let error = store.planningError, store.appScope != .newCourse {
                // Same reasoning as above — the modal could surface its
                // own error UI later, but for now route the user to the
                // full-screen retry surface.
                PlanningErrorView(
                    error: error,
                    onRetry: { store.send(.retryPlanningTapped) },
                    onUseDemo: { store.send(.useDemoFallbackTapped) },
                    onOpenSettings: { store.send(.openAPIKeySheet) }
                )
            } else if let outline = store.outlineProposal, store.appScope != .newCourse {
                // The modal renders the outline inline; this branch is
                // for the legacy `.course` refinement path that still
                // bumps to the full ProgramPreviewView.
                ProgramPreviewView(
                    outline: outline,
                    onStartLearning: { store.send(.outlineConfirmed) },
                    onRefineGoal: { store.send(.outlineRefined) }
                )
            } else {
                scopeView
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
    private var scopeView: some View {
        switch store.appScope {
        case .library:
            LibraryView(store: store)
        case .newCourse:
            NewCourseSheetView(store: store)
        case .course:
            courseShell
        }
    }

    /// In-course chrome — App Structure v2 `Shell` + `CourseSidebar`
    /// hosting `CourseHomeView` (the Map + Today merged surface).
    /// SessionWorkspace pushes via NavigationStack on top.
    private var courseShell: some View {
        NavigationStack {
            CourseHomeView(
                store: store.scope(state: \.courseHome, action: \.courseHome),
                onReturnToLibrary: { store.send(.returnToLibrary) },
                onSessionTapped: { id in
                    store.send(.courseHome(.sessionTapped(id)))
                }
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
