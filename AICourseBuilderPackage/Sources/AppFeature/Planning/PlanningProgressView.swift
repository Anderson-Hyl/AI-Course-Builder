import SwiftUI

/// Which planning call is currently in flight. Drives both the
/// `PlanningProgressView` copy and the retry routing in `AppFeature`.
public enum PlanningMode: Equatable, Sendable {
    /// Fast `generateOutline` pass before the user confirms.
    case outline
    /// Full `generateBlueprint` pass after confirmation.
    case full
}

/// Full-screen progress surface shown while the PlanningEngine runs a
/// structured-output call. No cancel button this pass — the worst case
/// is ~60s of waiting. `mode` swaps the heading + subtitle so the
/// outline pass and the full pass each get appropriate copy.
struct PlanningProgressView: View {
    var mode: PlanningMode = .full

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            VStack(spacing: 6) {
                Text(heading)
                    .font(.title3).bold()
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heading: String {
        switch mode {
        case .outline: "Drafting your outline…"
        case .full: "Designing your program…"
        }
    }

    private var subtitle: String {
        switch mode {
        case .outline: "Claude is sketching the high-level shape of your journey."
        case .full: "Claude is mapping your stages, sprints, and first session."
        }
    }
}
