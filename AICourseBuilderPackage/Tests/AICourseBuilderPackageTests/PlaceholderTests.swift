import Testing

/// Placeholder test stub so the test target builds. Real test bodies
/// (`SessionBlock` payload encode/decode, `LearningRepository` round-trips,
/// `Session` ordering invariants) ship in the next pass per
/// `ARCHITECTURE.md §13` test priorities.
@Suite("Placeholder")
struct PlaceholderTests {
    @Test func bootstrapCompiles() async throws {
        // Intentionally trivial — proves the test target wires correctly
        // against `swift test` so the next pass's real tests land into
        // a working harness.
        #expect(1 + 1 == 2)
    }
}
