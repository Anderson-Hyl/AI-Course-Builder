import SwiftUI

/// A single course tile in the Library grid. Header band carries a
/// glyph + tone-keyed colour (navy / warm / teal / accent). Below the
/// header sits the course title, stage line, a thin progress bar, and
/// a percent-complete row that flips its trailing label to "Active"
/// when this tile is the most recently played course.
///
/// Phase 2 ships with `progress` / `stageLine` / `eta` set to placeholders
/// for goals whose program hasn't loaded yet — Phase 4 (Course Home) will
/// pre-load and cache these values onto a sibling `CourseSummary` model
/// so the tile can show real progress at-a-glance.
public struct CourseTile: View {
    public enum Tone {
        case navy, warm, teal, accent
    }

    let glyph: String
    let title: String
    let stageLine: String
    let eta: String
    /// Progress from 0..1. Pass `nil` to hide the progress bar (e.g. a
    /// course whose program hasn't been generated yet).
    let progress: Double?
    let tone: Tone
    let isActive: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    public init(
        glyph: String,
        title: String,
        stageLine: String = "",
        eta: String = "",
        progress: Double? = nil,
        tone: Tone = .accent,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.glyph = glyph
        self.title = title
        self.stageLine = stageLine
        self.eta = eta
        self.progress = progress
        self.tone = tone
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                glyphHeader
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !stageLine.isEmpty || !eta.isEmpty {
                    Text(combinedMeta)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text.tertiary)
                        .lineLimit(1)
                }
                progressBar
                footerRow
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous)
                    .stroke(theme.border.regular, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var combinedMeta: String {
        switch (stageLine.isEmpty, eta.isEmpty) {
        case (false, false): "\(stageLine) · \(eta)"
        case (false, true): stageLine
        case (true, false): eta
        case (true, true): ""
        }
    }

    private var glyphHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(toneFill)
            Text(glyph)
                .font(.system(size: 32, weight: .semibold, design: tone == .warm ? .monospaced : .default))
                .tracking(tone == .warm ? 1.6 : -0.6)
                .foregroundStyle(toneForeground)
        }
        .frame(height: 96)
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.state.progressTrack)
                    Capsule()
                        .fill(isActive ? theme.accent.primary : theme.state.progressCurrent)
                        .frame(width: max(2, geo.size.width * max(0, min(1, progress))))
                }
            }
            .frame(height: 4)
        } else {
            Capsule()
                .fill(theme.state.progressTrack)
                .frame(height: 4)
        }
    }

    private var footerRow: some View {
        HStack {
            Text(percentLabel)
                .font(.system(size: 11))
                .foregroundStyle(theme.text.tertiary)
            Spacer(minLength: 0)
            if isActive {
                Text("Active")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent.primary)
            }
        }
    }

    private var percentLabel: String {
        if let progress {
            "\(Int((progress * 100).rounded()))% complete"
        } else {
            "Just started"
        }
    }

    private var toneFill: Color {
        switch tone {
        case .navy: theme.surface.sidebar
        case .warm: theme.accent.warm
        case .teal: theme.accent.teal
        case .accent: theme.accent.primary
        }
    }

    private var toneForeground: Color {
        switch tone {
        case .navy, .accent, .teal: .white
        case .warm: Color(.sRGB, red: 0.227, green: 0.141, blue: 0.027)  // dark warm-brown for legibility on the warm fill
        }
    }
}

/// Dashed-border tile that prompts the user to start a new course.
/// Renders next to the real `CourseTile`s in the Library grid.
public struct NewCourseTile: View {
    let action: () -> Void

    @Environment(\.theme) private var theme

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.accent.softFill)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.accent.primary)
                }
                .frame(width: 44, height: 44)
                Text("Generate a new course")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Text("Tell the AI what you want to learn.\nRefine the plan before you start.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.tile, style: .continuous)
                    .strokeBorder(theme.border.strong, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        CourseTile(
            glyph: "λ",
            title: "Haskell, end-to-end",
            stageLine: "Stage 1 of 4",
            eta: "≈ 18 weeks",
            progress: 0.21,
            tone: .navy,
            isActive: true,
            action: {}
        )
        CourseTile(
            glyph: "SPQR",
            title: "Roman republic to empire",
            stageLine: "Stage 1 of 5",
            eta: "≈ 9 weeks",
            progress: 0.12,
            tone: .warm,
            action: {}
        )
        CourseTile(
            glyph: "♪",
            title: "Music theory for songwriters",
            stageLine: "Stage 4 of 5",
            eta: "≈ 1 week",
            progress: 0.79,
            tone: .teal,
            action: {}
        )
        NewCourseTile(action: {})
    }
    .padding(28)
    .frame(width: 1100)
    .theme(.mvp)
}
