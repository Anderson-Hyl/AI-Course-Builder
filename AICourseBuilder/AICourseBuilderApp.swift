import AppFeature
import ComposableArchitecture
import Dependencies
import LearningDatabase
import LearningRepository
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct AICourseBuilderApp: App {
    let store: StoreOf<AppFeature>

    init() {
        // Bootstrap the local SQLite store and register the app-level
        // mutation observer so engine + repository writes can drive UI
        // transitions through the TCA store. `try!` here is intentional:
        // a failed schema migration on launch means the app cannot
        // function and should crash loudly rather than silently render
        // an empty Goal Intake.
        prepareDependencies {
            try! $0.bootstrapDatabase()
            $0.learningMutationObserver = AppLearningMutationObserver()
        }
        let store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
        self.store = store
        AppDelegateBridge.store = store
    }

    var body: some Scene {
        WindowGroup("AI Course Builder", id: "ai-course-builder-main") {
            AppView(store: store)
                #if os(macOS)
                .frame(minWidth: 880, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 760)
        #endif
    }
}

/// Shared static handle on the TCA store so the app-level mutation
/// observer (which runs from a non-isolated `@Dependency` closure) can
/// dispatch actions back into the reducer. Mirrors SlideFlow's
/// `AppDelegate.store` static — same pattern, same justification.
@MainActor
enum AppDelegateBridge {
    nonisolated(unsafe) static var store: StoreOf<AppFeature>?
}

/// Routes mutation hooks from `LearningRepository` to the `AppFeature`
/// TCA store. Fires identically whether the mutation originated from
/// Goal Intake's submit path, a future engine call (Planning /
/// Evaluation / Adaptation / Tutor), or any future tool surface — one
/// observer, one store, one UX path. Default no-op methods on the
/// protocol keep this struct minimal until more hooks earn a body.
struct AppLearningMutationObserver: LearningMutationObserver {
    func didCreateGoal(_ id: UUID) async {
        await MainActor.run {
            AppDelegateBridge.store?.send(.goalCreated(id))
        }
    }

    func didDeleteGoal(_ id: UUID) async {
        await MainActor.run {
            AppDelegateBridge.store?.send(.goalReset)
        }
    }

    func didCreateProgram(_ id: UUID, goalID: UUID) async {
        await MainActor.run {
            AppDelegateBridge.store?.send(.programCreated(id, goalID: goalID))
        }
    }

    func didChangeSessions(programID: UUID) async {
        await MainActor.run {
            AppDelegateBridge.store?.send(.sessionsChanged(programID: programID))
        }
    }
}
