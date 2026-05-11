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
            } else if store.isPlanning {
                PlanningProgressView(mode: store.pendingPlanningMode)
            } else if let error = store.planningError {
                PlanningErrorView(
                    error: error,
                    onRetry: { store.send(.retryPlanningTapped) },
                    onUseDemo: { store.send(.useDemoFallbackTapped) },
                    onOpenSettings: { store.send(.openAPIKeySheet) }
                )
            } else if let outline = store.outlineProposal {
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
            goalIntakeWrapped
        case .course:
            courseShell
        }
    }

    /// In-course chrome — still the legacy `SidebarShell` for Phase 2 so
    /// Home, Program Map, and SessionWorkspace push behave identically.
    /// Phase 4 replaces this with the new `Shell + CourseSidebar +
    /// CourseHomeView` combo.
    private var courseShell: some View {
        NavigationStack {
            SidebarShell(
                activeRoute: store.currentRoute,
                userName: store.profile?.displayName ?? "Learner",
                userRole: "learner",
                onSelectRoute: { store.send(.routeSelected($0)) }
            ) {
                VStack(spacing: 0) {
                    inCourseTopbar
                    routedContent
                }
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
    }

    /// Phase 2 stop-gap chrome that gives the user a way out of the
    /// in-course views back to the Library grid. Phase 4 replaces this
    /// with the new Topbar's breadcrumb (`Library › Course title`).
    private var inCourseTopbar: some View {
        HStack(spacing: 8) {
            Button {
                store.send(.returnToLibrary)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Library")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(theme.text.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(theme.surface.cardMuted, in: Capsule())
            }
            .buttonStyle(.plain)
            if let title = store.currentGoal?.normalizedTopic ?? store.currentGoal?.text {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(theme.surface.page)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.subtle)
                .frame(height: 1)
        }
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

    /// Phase 2 wrapper around the existing full-screen `GoalIntakeView`
    /// that adds a Cancel affordance so the user can back out to Library.
    /// Phase 3 turns this into a proper modal sheet with a streaming
    /// outline-preview side panel.
    private var goalIntakeWrapped: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    store.send(.goalIntakeCancelled)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(theme.text.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(theme.surface.cardMuted, in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("New course")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.text.tertiary)
                Spacer(minLength: 0)
                // Symmetric spacer to keep the title centered against the
                // Cancel button on the left.
                Color.clear.frame(width: 78, height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(theme.surface.page)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.border.subtle)
                    .frame(height: 1)
            }

            GoalIntakeView(
                store: store.scope(state: \.goalIntake, action: \.goalIntake)
            )
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
