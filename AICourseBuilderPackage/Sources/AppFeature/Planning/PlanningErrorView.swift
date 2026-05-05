import PlanningEngine
import SwiftUI

/// Surfaced when `PlanningEngine.generateBlueprint` fails. Routes the user
/// to "Add Key" when the cause is a missing API key, "Try Again" for
/// every other recoverable case, and an always-on "Use Demo Program"
/// escape hatch so the user is never wedged.
struct PlanningErrorView: View {
    let error: PlanningEngineError
    let onRetry: () -> Void
    let onUseDemo: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Couldn't generate your program")
                .font(.title2).bold()
            Text(error.localizedDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            HStack(spacing: 12) {
                if case .missingAPIKey = error {
                    Button("Add Key") { onOpenSettings() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Try Again") { onRetry() }
                        .buttonStyle(.borderedProminent)
                }
                Button("Use Demo Program") { onUseDemo() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
