import Foundation
import LearningModels
import Testing

/// Round-trip + snake_case key verification for every `BlockPayload.*`
/// struct. These are the highest-priority tests per `ARCHITECTURE.md §13`
/// — block serialization is the contract between the LLM-author path and
/// the renderer.
@Suite("BlockPayload coding")
struct BlockPayloadCodingTests {

    // MARK: - Round-trip

    @Test func titleRoundTrips() throws {
        try roundTrip(BlockPayload.Title(text: "Hello"))
    }

    @Test func objectiveRoundTrips() throws {
        try roundTrip(BlockPayload.Objective(statement: "Do the thing."))
    }

    @Test func conceptRoundTripsWithoutCallout() throws {
        try roundTrip(BlockPayload.Concept(heading: "H", body: "B"))
    }

    @Test func conceptRoundTripsWithCallout() throws {
        try roundTrip(BlockPayload.Concept(heading: "H", body: "B", callout: "C"))
    }

    @Test func exampleRoundTripsAllNil() throws {
        try roundTrip(BlockPayload.Example())
    }

    @Test func exampleRoundTripsAllPopulated() throws {
        try roundTrip(BlockPayload.Example(heading: "H", prose: "P", code: "let x = 1", language: "swift"))
    }

    @Test func codeExerciseRoundTrips() throws {
        try roundTrip(BlockPayload.CodeExercise(
            prompt: "p",
            language: "haskell",
            starterCode: "s",
            expectedSolution: "e",
            rubric: "r"
        ))
    }

    @Test func multipleChoiceRoundTrips() throws {
        try roundTrip(BlockPayload.MultipleChoice(
            question: "q",
            options: ["a", "b", "c"],
            correctIndex: 1,
            explanation: "x"
        ))
    }

    @Test func shortAnswerRoundTrips() throws {
        try roundTrip(BlockPayload.ShortAnswer(
            question: "q",
            expectedAnswer: "a",
            rubric: "r"
        ))
    }

    @Test func reflectionRoundTrips() throws {
        try roundTrip(BlockPayload.Reflection(prompt: "p"))
    }

    @Test func checkpointRoundTripsFreeText() throws {
        try roundTrip(BlockPayload.Checkpoint(prompt: "p"))
    }

    @Test func checkpointRoundTripsScale() throws {
        try roundTrip(BlockPayload.Checkpoint(
            prompt: "p",
            scaleMin: 1,
            scaleMax: 5,
            scaleLabels: ["a", "b", "c", "d", "e"]
        ))
    }

    @Test func reviewCardRoundTrips() throws {
        try roundTrip(BlockPayload.ReviewCard(
            conceptID: "11111111-1111-1111-1111-111111111111",
            front: "F",
            back: "B"
        ))
    }

    // MARK: - Snake-case key verification

    @Test func codeExerciseUsesSnakeCaseKeys() throws {
        let json = try jsonString(BlockPayload.CodeExercise(prompt: "p", language: "haskell", starterCode: "s", expectedSolution: "e"))
        #expect(json.contains("\"starter_code\""))
        #expect(json.contains("\"expected_solution\""))
        #expect(!json.contains("\"starterCode\""))
        #expect(!json.contains("\"expectedSolution\""))
    }

    @Test func multipleChoiceUsesSnakeCaseKey() throws {
        let json = try jsonString(BlockPayload.MultipleChoice(question: "q", options: ["a", "b"], correctIndex: 0))
        #expect(json.contains("\"correct_index\""))
        #expect(!json.contains("\"correctIndex\""))
    }

    @Test func shortAnswerUsesSnakeCaseKey() throws {
        let json = try jsonString(BlockPayload.ShortAnswer(question: "q", expectedAnswer: "a"))
        #expect(json.contains("\"expected_answer\""))
        #expect(!json.contains("\"expectedAnswer\""))
    }

    @Test func checkpointUsesSnakeCaseKeys() throws {
        let json = try jsonString(BlockPayload.Checkpoint(prompt: "p", scaleMin: 1, scaleMax: 5, scaleLabels: ["a"]))
        #expect(json.contains("\"scale_min\""))
        #expect(json.contains("\"scale_max\""))
        #expect(json.contains("\"scale_labels\""))
        #expect(!json.contains("\"scaleMin\""))
    }

    @Test func reviewCardUsesSnakeCaseKey() throws {
        let json = try jsonString(BlockPayload.ReviewCard(conceptID: "abc", front: "f", back: "b"))
        #expect(json.contains("\"concept_id\""))
        #expect(!json.contains("\"conceptID\""))
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        #expect(decoded == value)
    }

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
