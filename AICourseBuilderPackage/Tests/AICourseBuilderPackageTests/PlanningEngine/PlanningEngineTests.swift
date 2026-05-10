import ChatClients
import Dependencies
import Foundation
import LearningModels
import LearningRepository
import PlanningEngine
import Testing

/// Integration coverage for `PlanningEngine.liveValue`. Mocks `ChatClient`
/// (so we control the streamed events) and `APIKeyStore`, runs against a
/// real in-memory SQLite via `LearningRepository`. Asserts the four
/// happy/error paths the AppFeature reducer surfaces.
@MainActor
@Suite("PlanningEngine.liveValue")
struct PlanningEngineTests {

    @Test func generateBlueprintReturnsExistingProgramIDIdempotently() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
            $0.chatClient = ChatClient(
                stream: { _, _, _, _ in
                    Issue.record("ChatClient.stream should not be called when a program already exists")
                    return AsyncThrowingStream { $0.finish() }
                },
                isAvailable: { _ in true }
            )
            $0.apiKeyStore = makeAPIKeyStore(initial: "sk-ant-test")
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")
            let preexisting = try await repo.installDemoProgram(goalID: goalID)

            let result = try await PlanningEngine.liveValue.generateBlueprint(goalID, profile.id, false)
            #expect(result == preexisting)
        }
    }

    // The missing-API-key pre-check only fires when the platform's default
    // planning model is a provider that needs a key (`.anthropic`). On the
    // macOS dev target the default is `.claudeCodeCli`, which authenticates
    // out-of-band via the user's `claude login` session — there's no key
    // to be missing, so this contract doesn't apply.
    #if !os(macOS)
    @Test func generateBlueprintThrowsMissingAPIKeyWhenUnset() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
            $0.chatClient = ChatClient(
                stream: { _, _, _, _ in
                    AsyncThrowingStream { $0.finish() }
                },
                isAvailable: { _ in false }
            )
            $0.apiKeyStore = makeAPIKeyStore(initial: nil)
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            await #expect(throws: PlanningEngineError.missingAPIKey) {
                _ = try await PlanningEngine.liveValue.generateBlueprint(goalID, profile.id, false)
            }
        }
    }
    #endif

    @Test func generateBlueprintThrowsModelDidNotCallTool() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
            $0.chatClient = ChatClient(
                stream: { _, _, _, _ in
                    AsyncThrowingStream { continuation in
                        continuation.yield(.text("I refuse to call the tool."))
                        continuation.yield(.done(TurnSummary(stopReason: "end_turn")))
                        continuation.finish()
                    }
                },
                isAvailable: { _ in true }
            )
            $0.apiKeyStore = makeAPIKeyStore(initial: "sk-ant-test")
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            await #expect(throws: PlanningEngineError.modelDidNotCallTool(stopReason: "end_turn")) {
                _ = try await PlanningEngine.liveValue.generateBlueprint(goalID, profile.id, false)
            }
        }
    }

    @Test func generateBlueprintThrowsToolInputInvalidJSON() async throws {
        let database = try makeTestDatabase()
        try await withDependencies {
            $0.defaultDatabase = database
            $0.chatClient = ChatClient(
                stream: { _, _, _, _ in
                    AsyncThrowingStream { continuation in
                        let captured = CapturedToolCall(
                            id: "toolu_test",
                            name: "submit_blueprint",
                            inputJSON: Data("not valid json".utf8)
                        )
                        continuation.yield(.done(TurnSummary(capturedToolCall: captured)))
                        continuation.finish()
                    }
                },
                isAvailable: { _ in true }
            )
            $0.apiKeyStore = makeAPIKeyStore(initial: "sk-ant-test")
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            await #expect(throws: PlanningEngineError.self) {
                _ = try await PlanningEngine.liveValue.generateBlueprint(goalID, profile.id, false)
            }
        }
    }

    @Test func generateBlueprintHappyPathWritesEverything() async throws {
        let database = try makeTestDatabase()
        // Build the fixture bytes outside the @Sendable stream closure so
        // we don't reach back to the @MainActor-isolated test instance.
        let fixtureBytes = try JSONEncoder().encode(makeFixtureProposal())
        try await withDependencies {
            $0.defaultDatabase = database
            $0.chatClient = ChatClient(
                stream: { _, _, _, _ in
                    AsyncThrowingStream { continuation in
                        let captured = CapturedToolCall(
                            id: "toolu_test",
                            name: "submit_blueprint",
                            inputJSON: fixtureBytes
                        )
                        continuation.yield(.done(TurnSummary(capturedToolCall: captured)))
                        continuation.finish()
                    }
                },
                isAvailable: { _ in true }
            )
            $0.apiKeyStore = makeAPIKeyStore(initial: "sk-ant-test")
        } operation: {
            let repo = LearningRepository()
            let profile = try await repo.ensureCurrentProfile()
            let goalID = try await repo.createGoal(profileID: profile.id, text: "Learn Haskell")

            let programID = try await PlanningEngine.liveValue.generateBlueprint(goalID, profile.id, false)
            let program = try await repo.fetchProgram(forGoalID: goalID)
            #expect(program?.id == programID)

            let stages = try await repo.fetchStages(forProgramID: programID)
            #expect(stages.count == 5)
            #expect(stages.first?.status == Stage.Status.inProgress)

            let sessions = try await repo.fetchSessions(forProgramID: programID)
            #expect(!sessions.isEmpty)
            let blocks = try await repo.fetchBlocks(forSessionID: sessions[0].id)
            #expect(blocks.count == 10)
        }
    }

    // MARK: - Helpers

    private func makeAPIKeyStore(initial: String?) -> APIKeyStore {
        let storage = LockIsolated<String?>(initial)
        let baseURL = LockIsolated<String?>(nil)
        return APIKeyStore(
            get: { _ in storage.value },
            set: { _, value in
                storage.withValue { $0 = value.isEmpty ? nil : value }
            },
            remove: { _ in
                storage.withValue { $0 = nil }
            },
            getBaseURL: { _ in baseURL.value },
            setBaseURL: { _, value in
                baseURL.withValue { $0 = value.isEmpty ? nil : value }
            }
        )
    }

    private func makeFixtureProposal() -> BlueprintProposal {
        BlueprintProposal(
            program: .init(summary: "Mocked plan.", durationWeeks: 8),
            stages: (1...5).map { BlueprintProposal.Stage(order: $0, title: "Stage \($0)", intent: "i") },
            firstStageSprints: [BlueprintProposal.Sprint(order: 1, title: "Sprint 1", focus: "f")],
            firstSprintSessions: [
                BlueprintProposal.Session(order: 1, title: "S1", objective: "o", estimatedMinutes: 15)
            ],
            firstSessionBlocks: [
                blk(1, BlockKind.title, ["text": .string("L1")]),
                blk(2, BlockKind.objective, ["statement": .string("learn")]),
                blk(3, BlockKind.concept, ["heading": .string("h"), "body": .string("b")]),
                blk(4, BlockKind.example, ["prose": .string("hello")]),
                blk(5, BlockKind.codeExercise, ["prompt": .string("p"), "language": .string("haskell")]),
                blk(6, BlockKind.multipleChoice, [
                    "question": .string("q?"),
                    "options": .array([.string("a"), .string("b")]),
                    "correct_index": .int(1),
                ]),
                blk(7, BlockKind.shortAnswer, ["question": .string("q"), "expected_answer": .string("a")]),
                blk(8, BlockKind.reflection, ["prompt": .string("r")]),
                blk(9, BlockKind.checkpoint, ["prompt": .string("p")]),
                blk(10, BlockKind.reviewCard, [
                    "concept_id": .string(UUID().uuidString),
                    "front": .string("f"),
                    "back": .string("b"),
                ]),
            ]
        )
    }

    private func blk(_ order: Int, _ kind: String, _ fields: [String: JSONValue]) -> BlueprintProposal.Block {
        BlueprintProposal.Block(order: order, kind: kind, schemaVersion: 1, payload: .object(fields))
    }
}
