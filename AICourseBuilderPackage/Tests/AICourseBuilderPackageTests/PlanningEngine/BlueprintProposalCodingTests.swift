import Foundation
import PlanningEngine
import Testing

/// Round-trip + snake_case spot-checks for `BlueprintProposal`. The whole
/// LLM-output contract hinges on these JSON keys, so a failure here means
/// the planning prompt and the Swift type drifted apart.
@Suite("BlueprintProposal Codable")
struct BlueprintProposalCodingTests {

    @Test func proposalRoundTripsMinimalShape() throws {
        let proposal = makeMinimalProposal()
        let data = try JSONEncoder().encode(proposal)
        let decoded = try JSONDecoder().decode(BlueprintProposal.self, from: data)
        #expect(decoded == proposal)
    }

    @Test func proposalRoundTripsFullyPopulated() throws {
        let proposal = makeFullProposal()
        let data = try JSONEncoder().encode(proposal)
        let decoded = try JSONDecoder().decode(BlueprintProposal.self, from: data)
        #expect(decoded == proposal)
    }

    @Test func programUsesDurationWeeksSnakeCase() throws {
        let proposal = makeFullProposal()
        let json = try jsonString(for: proposal)
        #expect(json.contains("\"duration_weeks\""))
        #expect(!json.contains("\"durationWeeks\""))
    }

    @Test func proposalUsesNormalizedTopicSnakeCase() throws {
        let proposal = makeFullProposal()
        let json = try jsonString(for: proposal)
        #expect(json.contains("\"normalized_topic\""))
    }

    @Test func proposalUsesFirstStageSprintsSnakeCase() throws {
        let proposal = makeFullProposal()
        let json = try jsonString(for: proposal)
        #expect(json.contains("\"first_stage_sprints\""))
        #expect(!json.contains("\"firstStageSprints\""))
    }

    @Test func proposalUsesFirstSprintSessionsSnakeCase() throws {
        let proposal = makeFullProposal()
        let json = try jsonString(for: proposal)
        #expect(json.contains("\"first_sprint_sessions\""))
    }

    @Test func proposalUsesFirstSessionBlocksSnakeCase() throws {
        let proposal = makeFullProposal()
        let json = try jsonString(for: proposal)
        #expect(json.contains("\"first_session_blocks\""))
    }

    @Test func sessionUsesEstimatedMinutesSnakeCase() throws {
        let proposal = makeFullProposal()
        let json = try jsonString(for: proposal)
        #expect(json.contains("\"estimated_minutes\""))
        #expect(!json.contains("\"estimatedMinutes\""))
    }

    @Test func blockUsesSchemaVersionSnakeCase() throws {
        let proposal = makeFullProposal()
        let json = try jsonString(for: proposal)
        #expect(json.contains("\"schema_version\""))
    }

    @Test func blockPayloadAcceptsArbitraryShape() throws {
        let json = """
        {
          "program": { "summary": "x" },
          "stages": [
            { "order": 1, "title": "a", "intent": "i" },
            { "order": 2, "title": "b", "intent": "i" },
            { "order": 3, "title": "c", "intent": "i" },
            { "order": 4, "title": "d", "intent": "i" }
          ],
          "first_stage_sprints": [
            { "order": 1, "title": "sp", "focus": "f" }
          ],
          "first_sprint_sessions": [
            { "order": 1, "title": "ses", "objective": "o", "estimated_minutes": 15 }
          ],
          "first_session_blocks": [
            {
              "order": 1, "kind": "concept", "schema_version": 1,
              "payload": {
                "heading": "h",
                "body": "b",
                "nested": { "scale": [1, 2, 3], "active": true, "label": null }
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BlueprintProposal.self, from: json)
        #expect(decoded.firstSessionBlocks.first?.kind == "concept")
        if case .object(let dict) = decoded.firstSessionBlocks.first?.payload,
           case .object(let nested) = dict["nested"] {
            #expect(nested["active"] == .bool(true))
            #expect(nested["label"] == .null)
        } else {
            Issue.record("Expected nested object structure to round-trip")
        }
    }

    // MARK: - Builders

    private func makeMinimalProposal() -> BlueprintProposal {
        BlueprintProposal(
            program: .init(summary: "Learn Haskell from scratch."),
            stages: (1...4).map { BlueprintProposal.Stage(order: $0, title: "Stage \($0)", intent: "i\($0)") },
            firstStageSprints: [BlueprintProposal.Sprint(order: 1, title: "Sprint 1", focus: "f")],
            firstSprintSessions: [BlueprintProposal.Session(order: 1, title: "Session 1", objective: "o", estimatedMinutes: 15)],
            firstSessionBlocks: titleBlocks(count: 8)
        )
    }

    private func makeFullProposal() -> BlueprintProposal {
        BlueprintProposal(
            program: .init(summary: "Learn Haskell.", durationWeeks: 12),
            normalizedTopic: "haskell",
            stages: (1...5).map { BlueprintProposal.Stage(order: $0, title: "Stage \($0)", intent: "i\($0)") },
            firstStageSprints: [
                BlueprintProposal.Sprint(order: 1, title: "Sprint 1", focus: "f1"),
                BlueprintProposal.Sprint(order: 2, title: "Sprint 2", focus: "f2"),
            ],
            firstSprintSessions: [
                BlueprintProposal.Session(order: 1, title: "S1", objective: "o1", estimatedMinutes: 15),
                BlueprintProposal.Session(order: 2, title: "S2", objective: "o2", estimatedMinutes: 20),
            ],
            firstSessionBlocks: titleBlocks(count: 10)
        )
    }

    private func titleBlocks(count: Int) -> [BlueprintProposal.Block] {
        (1...count).map { index in
            BlueprintProposal.Block(
                order: index,
                kind: "title",
                schemaVersion: 1,
                payload: .object(["text": .string("Block \(index)")])
            )
        }
    }

    private func jsonString(for proposal: BlueprintProposal) throws -> String {
        let data = try JSONEncoder().encode(proposal)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
