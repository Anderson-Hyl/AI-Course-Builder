import Foundation

/// LLM-emitted plan, decoded from the `submit_blueprint` tool's input
/// JSON. Snake_case JSON keys via explicit `CodingKeys` (matches the
/// rest of the LLM-facing schema in `LearningModels/BlockPayloads.swift`).
///
/// Shape: program metadata, all stages (title-only stubs from stage 2
/// onward), every sprint inside stage 1, every session inside sprint 1
/// of stage 1, and the full ordered block list for session 1. The
/// translator persists these via `LearningRepository`'s create-call
/// sequence; later passes will expand sprints/sessions on demand.
public struct BlueprintProposal: Codable, Equatable, Sendable {
    public var program: Program
    public var normalizedTopic: String?
    public var stages: [Stage]
    public var firstStageSprints: [Sprint]
    public var firstSprintSessions: [Session]
    public var firstSessionBlocks: [Block]

    public enum CodingKeys: String, CodingKey {
        case program, stages
        case normalizedTopic = "normalized_topic"
        case firstStageSprints = "first_stage_sprints"
        case firstSprintSessions = "first_sprint_sessions"
        case firstSessionBlocks = "first_session_blocks"
    }

    public struct Program: Codable, Equatable, Sendable {
        public var summary: String
        public var durationWeeks: Int?

        public enum CodingKeys: String, CodingKey {
            case summary
            case durationWeeks = "duration_weeks"
        }

        public init(summary: String, durationWeeks: Int? = nil) {
            self.summary = summary
            self.durationWeeks = durationWeeks
        }
    }

    public struct Stage: Codable, Equatable, Sendable {
        public var order: Int
        public var title: String
        public var intent: String

        public init(order: Int, title: String, intent: String) {
            self.order = order
            self.title = title
            self.intent = intent
        }
    }

    public struct Sprint: Codable, Equatable, Sendable {
        public var order: Int
        public var title: String
        public var focus: String

        public init(order: Int, title: String, focus: String) {
            self.order = order
            self.title = title
            self.focus = focus
        }
    }

    public struct Session: Codable, Equatable, Sendable {
        public var order: Int
        public var title: String
        public var objective: String
        public var estimatedMinutes: Int

        public enum CodingKeys: String, CodingKey {
            case order, title, objective
            case estimatedMinutes = "estimated_minutes"
        }

        public init(order: Int, title: String, objective: String, estimatedMinutes: Int) {
            self.order = order
            self.title = title
            self.objective = objective
            self.estimatedMinutes = estimatedMinutes
        }
    }

    public struct Block: Codable, Equatable, Sendable {
        public var order: Int
        public var kind: String
        public var schemaVersion: Int
        public var payload: JSONValue

        public enum CodingKeys: String, CodingKey {
            case order, kind, payload
            case schemaVersion = "schema_version"
        }

        public init(order: Int, kind: String, schemaVersion: Int = 1, payload: JSONValue) {
            self.order = order
            self.kind = kind
            self.schemaVersion = schemaVersion
            self.payload = payload
        }
    }

    public init(
        program: Program,
        normalizedTopic: String? = nil,
        stages: [Stage],
        firstStageSprints: [Sprint],
        firstSprintSessions: [Session],
        firstSessionBlocks: [Block]
    ) {
        self.program = program
        self.normalizedTopic = normalizedTopic
        self.stages = stages
        self.firstStageSprints = firstStageSprints
        self.firstSprintSessions = firstSprintSessions
        self.firstSessionBlocks = firstSessionBlocks
    }
}
