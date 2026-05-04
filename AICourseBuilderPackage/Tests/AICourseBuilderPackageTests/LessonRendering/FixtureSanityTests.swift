import LearningModels
@testable import LessonRendering
import Testing

/// Sanity checks on the canonical fixtures so a renderer regression
/// shows up here before it shows up in a Preview.
@Suite("Fixture sanity")
struct FixtureSanityTests {

    @Test func haskellSessionCoversAllKnownKinds() {
        let kinds = Set(Fixtures.haskellSessionBlocks.map(\.kind))
        #expect(kinds == Set(BlockKind.all))
    }

    @Test func haskellSessionOrdersAreContiguousFromOne() {
        let orders = Fixtures.haskellSessionBlocks.map(\.order).sorted()
        #expect(orders == Array(1...10))
    }

    @Test func mathSessionOrdersAreContiguousFromOne() {
        let orders = Fixtures.mathSessionBlocks.map(\.order).sorted()
        #expect(orders == Array(1...9))
    }

    @Test func chemistrySessionOrdersAreContiguousFromOne() {
        let orders = Fixtures.chemistrySessionBlocks.map(\.order).sorted()
        #expect(orders == Array(1...9))
    }

    @Test func nonProgrammingFixturesAvoidCodeExercise() {
        // `code_exercise` is programming-specific until a subject-agnostic
        // exercise kind (or subject-specific equivalents like
        // `derivation_step`, `chem_equation_balance`) lands.
        let mathKinds = Set(Fixtures.mathSessionBlocks.map(\.kind))
        let chemKinds = Set(Fixtures.chemistrySessionBlocks.map(\.kind))
        #expect(!mathKinds.contains(BlockKind.codeExercise))
        #expect(!chemKinds.contains(BlockKind.codeExercise))
    }

    @Test func everyFixtureBlockHasNonEmptyPayloadJSON() {
        let allBlocks = Fixtures.haskellSessionBlocks
            + Fixtures.mathSessionBlocks
            + Fixtures.chemistrySessionBlocks
        for block in allBlocks {
            #expect(!block.payloadJSON.isEmpty, "block \(block.kind) at order \(block.order) has empty payload")
            #expect(block.payloadJSON != "{}", "block \(block.kind) at order \(block.order) encoded to empty object")
        }
    }
}
