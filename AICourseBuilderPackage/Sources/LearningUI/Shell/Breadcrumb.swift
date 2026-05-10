import SwiftUI

/// Renders a `[BreadcrumbSegment]` as `Library / Course / Session`. The
/// last segment is the current location (text-primary, weight-medium);
/// earlier segments dim to text-secondary and become tappable when the
/// caller supplied an `action`. Slash separators are tertiary so the
/// segments do the visual work.
struct Breadcrumb: View {
    let segments: [BreadcrumbSegment]

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                if index > 0 {
                    Text("/")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.text.tertiary)
                }
                segmentView(segment, isCurrent: index == segments.count - 1)
            }
        }
        .padding(.leading, 16)
        .lineLimit(1)
    }

    @ViewBuilder
    private func segmentView(_ segment: BreadcrumbSegment, isCurrent: Bool) -> some View {
        if let action = segment.action, !isCurrent {
            Button(action: action) {
                segmentLabel(segment.title, isCurrent: isCurrent)
            }
            .buttonStyle(.plain)
        } else {
            segmentLabel(segment.title, isCurrent: isCurrent)
        }
    }

    @ViewBuilder
    private func segmentLabel(_ title: String, isCurrent: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: isCurrent ? .medium : .regular))
            .foregroundStyle(isCurrent ? theme.text.primary : theme.text.secondary)
    }
}
