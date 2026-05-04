import Foundation
import LearningModels
import Testing

/// Round-trip + snake_case key verification for `AttemptInput.*` and
/// `AttemptResult.*`. Same shape as `BlockPayloadCodingTests` — these are
/// the contract between renderer (input capture) and persistence /
/// `EvaluationEngine` (verdict storage).
@Suite("AttemptPayload coding")
struct AttemptPayloadCodingTests {

    @Test func multipleChoiceInputRoundTrips() throws {
        try roundTrip(AttemptInput.MultipleChoice(selectedIndex: 2))
    }

    @Test func multipleChoiceResultRoundTripsCorrect() throws {
        try roundTrip(AttemptResult.MultipleChoice(correct: true, score: 1.0, feedback: "Nice."))
    }

    @Test func multipleChoiceResultRoundTripsIncorrectWithoutFeedback() throws {
        try roundTrip(AttemptResult.MultipleChoice(correct: false, score: 0.0))
    }

    @Test func multipleChoiceInputUsesSnakeCaseKey() throws {
        let json = try jsonString(AttemptInput.MultipleChoice(selectedIndex: 0))
        #expect(json.contains("\"selected_index\""))
        #expect(!json.contains("\"selectedIndex\""))
    }

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
