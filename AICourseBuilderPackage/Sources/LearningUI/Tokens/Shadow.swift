import CoreGraphics
import SwiftUI

/// Shadow tokens. CSS uses `0 24px 60px <rgba>`; SwiftUI's
/// `View.shadow(color:radius:x:y:)` interprets `radius` as a Gaussian
/// blur in points and `y` as a vertical offset in points. The values
/// here are picked so a SwiftUI rendered card reads with a similar
/// weight to the design-board reference.
public struct CourseBuilderShadow: Sendable {
    public struct Style: Sendable {
        public var color: Color
        public var radius: CGFloat
        public var x: CGFloat
        public var y: CGFloat

        public init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }

    public var card: Style
    public var float: Style
    public var accentPrimary: Style

    public init(card: Style, float: Style, accentPrimary: Style) {
        self.card = card
        self.float = float
        self.accentPrimary = accentPrimary
    }
}

public extension View {
    /// Apply a `CourseBuilderShadow.Style` token without unpacking each
    /// field at the call site.
    func shadow(_ style: CourseBuilderShadow.Style) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
