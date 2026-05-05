import SwiftUI

/// Horizontal row of progress dots from the design board's `.progress-row`.
/// Renders `total` dots (capped at 10) where the first `completed` are
/// filled with `progressComplete`, the next dot (if any) is rendered as
/// `progressCurrent`, and remaining dots are `progressTrack`.
public struct ProgressDots: View {
    let total: Int
    let completed: Int

    @Environment(\.theme) private var theme

    public init(total: Int, completed: Int) {
        self.total = total
        self.completed = completed
    }

    public var body: some View {
        let cap = 10
        let visible = min(total, cap)
        HStack(spacing: theme.spacing.xs) {
            ForEach(0..<visible, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 10)
            }
            if total > cap {
                Text("+\(total - cap)")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.tertiary)
                    .padding(.leading, theme.spacing.xs)
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index < completed { return theme.state.progressComplete }
        if index == completed { return theme.state.progressCurrent }
        return theme.state.progressTrack
    }
}
