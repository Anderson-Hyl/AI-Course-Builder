import SwiftUI

/// Full-screen "Designing your program…" surface shown while the
/// PlanningEngine runs a structured-output call. No cancel button this
/// pass — the worst case is ~60s of waiting.
struct PlanningProgressView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            VStack(spacing: 6) {
                Text("Designing your program…")
                    .font(.title3).bold()
                Text("Claude is mapping your stages, sprints, and first session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
