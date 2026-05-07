import ChatClients
import Dependencies
import DependenciesMacros
import Foundation
import LearningModels
import LearningRepository

/// Goal decomposition engine. Takes a `LearningGoal` (+ `LearnerProfile`)
/// and produces a `ProgramBlueprint` plus a fully-detailed first session
/// via one Anthropic tool call. Stages 2+ stay as title-only stubs;
/// later passes will expand sprints/sessions on demand.
///
/// Idempotent: if a program already exists for the goal AND
/// `regenerate == false`, returns the existing id without calling the
/// LLM. Engines that want a fresh plan pass `regenerate: true`.
@DependencyClient
public struct PlanningEngine: Sendable {
    public var generateBlueprint: @Sendable (
        _ goalID: LearningGoal.ID,
        _ profileID: LearnerProfile.ID,
        _ regenerate: Bool
    ) async throws -> ProgramBlueprint.ID

    /// Fast outline pass: emits a full ordered stage list (with intent)
    /// plus program summary and duration estimate — no sprints, sessions,
    /// or blocks. Returned in-memory; the AppFeature reducer drives the
    /// Program Preview screen off the result. Lazy expansion of the
    /// downstream layers happens on confirmation.
    public var generateOutline: @Sendable (
        _ goalID: LearningGoal.ID,
        _ profileID: LearnerProfile.ID
    ) async throws -> OutlineProposal
}

extension PlanningEngine: DependencyKey {
    public static var liveValue: PlanningEngine {
        PlanningEngine(
            generateBlueprint: { goalID, _, regenerate in
                @Dependency(\.learningRepository) var repository
                @Dependency(\.chatClient) var chatClient
                @Dependency(\.apiKeyStore) var apiKeyStore

                if !regenerate, let existing = try await repository.fetchProgram(forGoalID: goalID) {
                    return existing.id
                }

                let key = (try? apiKeyStore.get(provider: .anthropic)) ?? nil
                guard let key, !key.isEmpty else {
                    throw PlanningEngineError.missingAPIKey
                }

                let goals = try await repository.fetchAllGoals()
                guard let goal = goals.first(where: { $0.id == goalID }) else {
                    throw PlanningEngineError.translationFailed(
                        underlying: LearningRepositoryError.goalNotFound(goalID)
                    )
                }
                let profile = try await repository.ensureCurrentProfile()

                let messages = PlanningPrompt.buildMessages(goal: goal, profile: profile)
                let toolSpec = ToolSpec(
                    name: "submit_blueprint",
                    description: "Submit the structured learning program plan as JSON. Call exactly once.",
                    inputSchemaJSON: PlanningPrompt.submitBlueprintSchemaJSON
                )

                var captured: CapturedToolCall?
                var lastStopReason: String?
                do {
                    for try await event in chatClient.stream(
                        messages,
                        .claudeOpus47,
                        [toolSpec],
                        .tool(name: "submit_blueprint")
                    ) {
                        switch event {
                        case .text:
                            continue
                        case .done(let summary):
                            captured = summary.capturedToolCall
                            lastStopReason = summary.stopReason
                        }
                    }
                } catch is CancellationError {
                    throw PlanningEngineError.cancelled
                } catch let error as ChatClientError {
                    if case .missingAPIKey = error {
                        throw PlanningEngineError.missingAPIKey
                    }
                    throw PlanningEngineError.network(error.errorDescription ?? error.localizedDescription)
                } catch {
                    throw PlanningEngineError.network(error.localizedDescription)
                }

                guard let toolCall = captured else {
                    throw PlanningEngineError.modelDidNotCallTool(stopReason: lastStopReason)
                }

                let proposal: BlueprintProposal
                do {
                    proposal = try JSONDecoder().decode(BlueprintProposal.self, from: toolCall.inputJSON)
                } catch {
                    throw PlanningEngineError.toolInputInvalidJSON(error.localizedDescription)
                }

                try BlueprintProposalValidator.validate(proposal)

                return try await BlueprintTranslator.translate(
                    proposal,
                    goalID: goalID,
                    repository: repository
                )
            },
            generateOutline: { goalID, _ in
                @Dependency(\.learningRepository) var repository
                @Dependency(\.chatClient) var chatClient
                @Dependency(\.apiKeyStore) var apiKeyStore

                let key = (try? apiKeyStore.get(provider: .anthropic)) ?? nil
                guard let key, !key.isEmpty else {
                    throw PlanningEngineError.missingAPIKey
                }

                let goals = try await repository.fetchAllGoals()
                guard let goal = goals.first(where: { $0.id == goalID }) else {
                    throw PlanningEngineError.translationFailed(
                        underlying: LearningRepositoryError.goalNotFound(goalID)
                    )
                }
                let profile = try await repository.ensureCurrentProfile()

                let messages = PlanningPrompt.buildOutlineMessages(goal: goal, profile: profile)
                let toolSpec = ToolSpec(
                    name: "submit_outline",
                    description: "Submit the high-level program outline (summary + stage list) as JSON. Call exactly once.",
                    inputSchemaJSON: PlanningPrompt.submitOutlineSchemaJSON
                )

                var captured: CapturedToolCall?
                var lastStopReason: String?
                do {
                    for try await event in chatClient.stream(
                        messages,
                        .claudeOpus47,
                        [toolSpec],
                        .tool(name: "submit_outline")
                    ) {
                        switch event {
                        case .text:
                            continue
                        case .done(let summary):
                            captured = summary.capturedToolCall
                            lastStopReason = summary.stopReason
                        }
                    }
                } catch is CancellationError {
                    throw PlanningEngineError.cancelled
                } catch let error as ChatClientError {
                    if case .missingAPIKey = error {
                        throw PlanningEngineError.missingAPIKey
                    }
                    throw PlanningEngineError.network(error.errorDescription ?? error.localizedDescription)
                } catch {
                    throw PlanningEngineError.network(error.localizedDescription)
                }

                guard let toolCall = captured else {
                    throw PlanningEngineError.modelDidNotCallTool(stopReason: lastStopReason)
                }

                let proposal: OutlineProposal
                do {
                    proposal = try JSONDecoder().decode(OutlineProposal.self, from: toolCall.inputJSON)
                } catch {
                    throw PlanningEngineError.toolInputInvalidJSON(error.localizedDescription)
                }

                try BlueprintProposalValidator.validateOutline(proposal)

                return proposal
            }
        )
    }

    public static var testValue: PlanningEngine { PlanningEngine() }
}

extension DependencyValues {
    public var planningEngine: PlanningEngine {
        get { self[PlanningEngine.self] }
        set { self[PlanningEngine.self] = newValue }
    }
}
