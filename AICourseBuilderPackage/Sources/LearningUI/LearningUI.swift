/// Namespace for app-specific design extras (chips, status pills, course
/// badges) that don't belong in a generic design library.
///
/// **Empty by design** as of the bootstrap pass. The full design system
/// wires in next pass when the remote `UIComponents` library lands and
/// `@Environment(\.theme)` token thread-through is set up. Until then,
/// `AppFeature` uses plain SwiftUI + system colors so the bootstrap stays
/// small.
public enum LearningUI {}
