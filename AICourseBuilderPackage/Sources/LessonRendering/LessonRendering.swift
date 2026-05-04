/// Block-to-SwiftUI renderers for `SessionBlock`. Each `BlockKind` gets a
/// dedicated native view that decodes the matching `BlockPayload` struct
/// and renders deterministically — no LLM-generated UI code, ever.
///
/// Public entry points:
/// - `BlockView` — renders a single `SessionBlock` row.
/// - `SessionBlockList` — renders an ordered list of `SessionBlock` rows.
///
/// Dispatch is handled by the internal `BlockDispatch.resolve(_:)`. Unknown
/// kinds, unsupported schema versions, and malformed payloads each surface
/// a distinct placeholder so failures are loud rather than silent.
///
/// See `ARCHITECTURE.md §6` for the rendering rule (typed schema, never
/// persist UI source).
public enum LessonRendering {}
