import SwiftUI

/// Gradient-filled progress bar from the design board's
/// `.milestone-track`. `progress` is clamped to `0...1`.
public struct MilestoneTrack: View {
    let progress: Double

    @Environment(\.theme) private var theme

    public init(progress: Double) {
        self.progress = max(0, min(1, progress))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.state.progressTrack)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [theme.accent.primary, theme.state.progressCurrent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 8)
    }
}
