import SwiftUI

/// Top-row metric tile from the design board's `.metric-pill`. Three
/// stacked rows: a small label, the metric main row (optional badge +
/// value), and a tertiary caption.
public struct MetricPill<Leading: View>: View {
    let label: String
    let value: String
    let caption: String?
    let leading: Leading
    /// `true` for tiles with no real data behind them yet — softens the
    /// value text so it's obvious to a reviewer the column is a stub.
    let isPlaceholder: Bool

    @Environment(\.theme) private var theme

    public init(
        label: String,
        value: String,
        caption: String? = nil,
        isPlaceholder: Bool = false,
        @ViewBuilder leading: () -> Leading
    ) {
        self.label = label
        self.value = value
        self.caption = caption
        self.isPlaceholder = isPlaceholder
        self.leading = leading()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
            HStack(spacing: theme.spacing.md) {
                leading
                Text(value)
                    .font(theme.typography.metricValue)
                    .foregroundStyle(isPlaceholder ? theme.text.tertiary : theme.text.primary)
                    .lineLimit(1)
            }
            if let caption {
                Text(caption)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.text.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.regular)
        .background(theme.surface.card, in: RoundedRectangle(cornerRadius: theme.radius.tile))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.tile)
                .stroke(theme.border.regular, lineWidth: 1)
        )
    }
}

public extension MetricPill where Leading == EmptyView {
    init(
        label: String,
        value: String,
        caption: String? = nil,
        isPlaceholder: Bool = false
    ) {
        self.init(
            label: label,
            value: value,
            caption: caption,
            isPlaceholder: isPlaceholder,
            leading: { EmptyView() }
        )
    }
}
