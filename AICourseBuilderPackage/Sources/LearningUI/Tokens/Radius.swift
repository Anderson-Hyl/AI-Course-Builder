import CoreGraphics

/// Corner-radius tokens. Names follow the role they play in the design
/// board (`chip`, `badge`, `input`, …) so a future tweak to the chip
/// radius doesn't have to chase down the only `9` in the codebase.
public struct CourseBuilderRadius: Sendable {
    public var chip: CGFloat
    public var badge: CGFloat
    public var input: CGFloat
    public var tile: CGFloat
    public var card: CGFloat
    public var shell: CGFloat
    public var hero: CGFloat
    /// Use `.infinity` to fully round capsule-style controls (buttons,
    /// nav pills, progress dots).
    public var pill: CGFloat

    public init(
        chip: CGFloat,
        badge: CGFloat,
        input: CGFloat,
        tile: CGFloat,
        card: CGFloat,
        shell: CGFloat,
        hero: CGFloat,
        pill: CGFloat
    ) {
        self.chip = chip
        self.badge = badge
        self.input = input
        self.tile = tile
        self.card = card
        self.shell = shell
        self.hero = hero
        self.pill = pill
    }
}

public extension CourseBuilderRadius {
    static let mvp = CourseBuilderRadius(
        chip: 9,
        badge: 12,
        input: 14,
        tile: 16,
        card: 18,
        shell: 22,
        hero: 28,
        pill: .infinity
    )
}
