import Foundation

/// Typed payloads for each `SessionBlock.kind`. Encoded into
/// `SessionBlock.payloadJSON` via JSONEncoder; decoded on render. Each
/// payload exposes `currentSchemaVersion` so callers writing new blocks
/// stamp `SessionBlock.schemaVersion` consistently.
///
/// **Snake_case JSON keys** via explicit `CodingKeys` so the LLM's output
/// round-trips cleanly without per-field bridging. Swift call sites use
/// camelCase as normal.
///
/// Conventions:
/// - Optional fields stay optional in JSON (omitted when nil).
/// - Adding an optional field is non-breaking — DON'T bump the version.
/// - Removing or renaming a field IS breaking — bump the version and add
///   a renderer branch for the prior version that maps the old shape.
public enum BlockPayload {}

// MARK: - title

extension BlockPayload {
    public struct Title: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var text: String

        public init(text: String) {
            self.text = text
        }
    }
}

// MARK: - objective

extension BlockPayload {
    public struct Objective: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var statement: String

        public init(statement: String) {
            self.statement = statement
        }
    }
}

// MARK: - concept

extension BlockPayload {
    public struct Concept: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var heading: String
        /// Concept body in light Markdown (paragraphs, inline code, lists).
        /// The renderer strips anything beyond a small whitelist so the
        /// LLM can't smuggle in formatting that breaks layout.
        public var body: String
        /// Optional pull-quote / TL;DR rendered as a callout above the
        /// body. Often used to anchor the "why" before the "what".
        public var callout: String?

        public init(heading: String, body: String, callout: String? = nil) {
            self.heading = heading
            self.body = body
            self.callout = callout
        }
    }
}

// MARK: - example

extension BlockPayload {
    public struct Example: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var heading: String?
        /// Optional human-readable explanation surrounding the code snippet.
        public var prose: String?
        /// Optional code snippet. Either `prose` or `code` (or both)
        /// must be non-nil at render time — the LLM gets a system-prompt
        /// reminder to that effect.
        public var code: String?
        /// Language tag (`haskell`, `swift`, …) to drive syntax highlighting
        /// in the renderer. Optional — renderer falls back to plain text.
        public var language: String?

        public init(heading: String? = nil, prose: String? = nil, code: String? = nil, language: String? = nil) {
            self.heading = heading
            self.prose = prose
            self.code = code
            self.language = language
        }
    }
}

// MARK: - code_exercise

extension BlockPayload {
    public struct CodeExercise: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var prompt: String
        public var language: String
        /// Pre-filled code the learner edits. Optional — for fill-in
        /// exercises this is a stub; for "write from scratch" it's nil.
        public var starterCode: String?
        /// Reference solution the evaluator checks against. Hidden from the
        /// learner during the attempt; surfaced after submit.
        public var expectedSolution: String?
        /// Free-text rubric the LLM evaluator uses when comparing the
        /// learner's attempt to `expectedSolution`. Heuristic-eval first,
        /// real eval after MVP — see `EvaluationEngine`.
        public var rubric: String?

        public enum CodingKeys: String, CodingKey {
            case prompt, language
            case starterCode = "starter_code"
            case expectedSolution = "expected_solution"
            case rubric
        }

        public init(prompt: String, language: String, starterCode: String? = nil, expectedSolution: String? = nil, rubric: String? = nil) {
            self.prompt = prompt
            self.language = language
            self.starterCode = starterCode
            self.expectedSolution = expectedSolution
            self.rubric = rubric
        }
    }
}

// MARK: - multiple_choice

extension BlockPayload {
    public struct MultipleChoice: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var question: String
        /// Display order matters — the renderer doesn't shuffle. The LLM
        /// is responsible for non-trivially varying the position of the
        /// correct answer across questions.
        public var options: [String]
        /// Zero-based index into `options`. Validated at decode-time —
        /// out-of-range surfaces a parse error during persistence so the
        /// LLM is forced to retry rather than ship a broken question.
        public var correctIndex: Int
        public var explanation: String?

        public enum CodingKeys: String, CodingKey {
            case question, options, explanation
            case correctIndex = "correct_index"
        }

        public init(question: String, options: [String], correctIndex: Int, explanation: String? = nil) {
            self.question = question
            self.options = options
            self.correctIndex = correctIndex
            self.explanation = explanation
        }
    }
}

// MARK: - short_answer

extension BlockPayload {
    public struct ShortAnswer: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var question: String
        /// Free-text answer key the LLM evaluator compares against.
        public var expectedAnswer: String
        public var rubric: String?

        public enum CodingKeys: String, CodingKey {
            case question, rubric
            case expectedAnswer = "expected_answer"
        }

        public init(question: String, expectedAnswer: String, rubric: String? = nil) {
            self.question = question
            self.expectedAnswer = expectedAnswer
            self.rubric = rubric
        }
    }
}

// MARK: - reflection

extension BlockPayload {
    public struct Reflection: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        public var prompt: String

        public init(prompt: String) {
            self.prompt = prompt
        }
    }
}

// MARK: - checkpoint

extension BlockPayload {
    public struct Checkpoint: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        /// Question or self-rated confidence prompt the learner answers
        /// before progressing. Used by `AdaptationEngine` to decide
        /// whether to advance, slow down, or insert review.
        public var prompt: String
        /// Optional structured rating scale; nil means free-text response.
        public var scaleMin: Int?
        public var scaleMax: Int?
        public var scaleLabels: [String]?

        public enum CodingKeys: String, CodingKey {
            case prompt
            case scaleMin = "scale_min"
            case scaleMax = "scale_max"
            case scaleLabels = "scale_labels"
        }

        public init(prompt: String, scaleMin: Int? = nil, scaleMax: Int? = nil, scaleLabels: [String]? = nil) {
            self.prompt = prompt
            self.scaleMin = scaleMin
            self.scaleMax = scaleMax
            self.scaleLabels = scaleLabels
        }
    }
}

// MARK: - review_card

extension BlockPayload {
    public struct ReviewCard: Codable, Equatable, Sendable {
        public static let currentSchemaVersion = 1
        /// The concept being reviewed — references a `ConceptNode.id`
        /// stringified. The renderer can show the concept's title from a
        /// repository lookup, but the card stands alone if the concept
        /// row is missing (defensive — sync timing).
        public var conceptID: String
        /// Cue / question side of the flashcard.
        public var front: String
        /// Answer side revealed after the learner attempts a recall.
        public var back: String

        public enum CodingKeys: String, CodingKey {
            case front, back
            case conceptID = "concept_id"
        }

        public init(conceptID: String, front: String, back: String) {
            self.conceptID = conceptID
            self.front = front
            self.back = back
        }
    }
}
