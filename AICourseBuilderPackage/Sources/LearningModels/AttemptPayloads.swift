import Foundation

/// Typed payloads for `Attempt.inputJSON` — what the learner submitted.
/// Mirrors the per-kind discipline of `BlockPayload`: snake_case JSON keys
/// via explicit `CodingKeys`, `currentSchemaVersion` literal on each
/// payload, additive optional fields are non-breaking.
///
/// Shapes are scoped per block kind. The renderer + `EvaluationEngine`
/// agree on the shape per kind; nothing else inspects them.
public enum AttemptInput {}

extension AttemptInput {
    public struct MultipleChoice: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        /// Zero-based index into the question's `options` array. Validated
        /// against `MultipleChoice.options.count` at submit time — out-of-
        /// range values surface as a record error rather than persisting a
        /// silent miss.
        public var selectedIndex: Int

        public enum CodingKeys: String, CodingKey {
            case selectedIndex = "selected_index"
        }

        public init(selectedIndex: Int) {
            self.selectedIndex = selectedIndex
        }
    }
}

/// Typed payloads for `Attempt.resultJSON` — the evaluator's verdict.
/// Same per-kind discipline as `AttemptInput`.
public enum AttemptResult {}

extension AttemptResult {
    public struct MultipleChoice: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var correct: Bool
        /// Normalized 0...1 score. For multiple-choice this is 1.0 or 0.0
        /// today; reserved for partial credit if a question gains weighted
        /// options later.
        public var score: Double
        /// Optional free-text feedback. For multiple-choice this echoes
        /// the question's `explanation` so the learner sees the same text
        /// regardless of which option they picked.
        public var feedback: String?

        public init(correct: Bool, score: Double, feedback: String? = nil) {
            self.correct = correct
            self.score = score
            self.feedback = feedback
        }
    }
}
