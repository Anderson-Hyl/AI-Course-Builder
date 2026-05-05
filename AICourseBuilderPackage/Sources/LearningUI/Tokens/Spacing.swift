import CoreGraphics

/// Numeric spacing scale lifted from the gap/padding distribution in
/// `design/mvp-design-board.html`. Use named scales rather than raw
/// numbers so layout tweaks land in one place.
public struct CourseBuilderSpacing: Sendable {
    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var regular: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat
    public var xxl: CGFloat
    public var xxxl: CGFloat

    public init(
        xs: CGFloat,
        sm: CGFloat,
        md: CGFloat,
        regular: CGFloat,
        lg: CGFloat,
        xl: CGFloat,
        xxl: CGFloat,
        xxxl: CGFloat
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.regular = regular
        self.lg = lg
        self.xl = xl
        self.xxl = xxl
        self.xxxl = xxxl
    }
}

public extension CourseBuilderSpacing {
    static let mvp = CourseBuilderSpacing(
        xs: 8,
        sm: 10,
        md: 12,
        regular: 14,
        lg: 16,
        xl: 18,
        xxl: 24,
        xxxl: 28
    )
}
