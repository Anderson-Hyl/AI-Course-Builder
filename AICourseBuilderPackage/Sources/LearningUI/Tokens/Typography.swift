import SwiftUI

/// Type scale lifted from `design/mvp-design-board.html`. Names describe
/// role rather than size so renames don't ripple when the design tweaks
/// a value. Tracking values are converted from CSS `letter-spacing` em to
/// SwiftUI's point-tracking by multiplying by the base font size.
public struct CourseBuilderTypography: Sendable {
    public var heroHeading: Font
    public var pageTitle: Font
    public var sectionTitle: Font
    public var sessionTitle: Font
    public var cardTitle: Font
    public var metricValue: Font
    public var body: Font
    public var bodySmall: Font
    public var label: Font
    public var caption: Font
    public var buttonLabel: Font

    public init(
        heroHeading: Font,
        pageTitle: Font,
        sectionTitle: Font,
        sessionTitle: Font,
        cardTitle: Font,
        metricValue: Font,
        body: Font,
        bodySmall: Font,
        label: Font,
        caption: Font,
        buttonLabel: Font
    ) {
        self.heroHeading = heroHeading
        self.pageTitle = pageTitle
        self.sectionTitle = sectionTitle
        self.sessionTitle = sessionTitle
        self.cardTitle = cardTitle
        self.metricValue = metricValue
        self.body = body
        self.bodySmall = bodySmall
        self.label = label
        self.caption = caption
        self.buttonLabel = buttonLabel
    }
}

public extension CourseBuilderTypography {
    static let mvp = CourseBuilderTypography(
        heroHeading: .system(size: 56, weight: .bold, design: .default),
        pageTitle: .system(size: 36, weight: .bold, design: .default),
        sectionTitle: .system(size: 30, weight: .bold, design: .default),
        sessionTitle: .system(size: 27, weight: .semibold, design: .default),
        cardTitle: .system(size: 22, weight: .semibold, design: .default),
        metricValue: .system(size: 22, weight: .bold, design: .default),
        body: .system(size: 14, weight: .regular, design: .default),
        bodySmall: .system(size: 13, weight: .regular, design: .default),
        label: .system(size: 11, weight: .bold, design: .default),
        caption: .system(size: 12, weight: .regular, design: .default),
        buttonLabel: .system(size: 14, weight: .semibold, design: .default)
    )
}
