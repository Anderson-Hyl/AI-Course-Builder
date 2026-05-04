import SwiftUI

/// Threads the active `CourseBuilderThemePalette` through the SwiftUI
/// environment so block renderers, screen views, and shared chrome read
/// theme tokens uniformly without prop-drilling.
///
/// Default value is `.mvp` so Previews and ad-hoc views render with sane
/// colors even when the host scene forgets to inject a palette.
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: CourseBuilderThemePalette = .mvp
}

public extension EnvironmentValues {
    var theme: CourseBuilderThemePalette {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

public extension View {
    /// Inject a `CourseBuilderThemePalette` into the environment for this
    /// subtree. Call once at the app root with `.theme(.mvp)`.
    func theme(_ palette: CourseBuilderThemePalette) -> some View {
        environment(\.theme, palette)
    }
}
