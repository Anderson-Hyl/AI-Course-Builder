import ChatClients
import Dependencies
import DependenciesMacros
import Foundation
import LearningModels
import LearningRepository

/// Next-step decision engine. Takes a session the learner just finished
/// and produces a `session_adaptation` artifact: per-concept mastery
/// estimates, a small batch of `ReviewItem` rows scheduled out by SM-2
/// intervals, and a structured next-step recommendation. The session
/// itself is marked `completed` (with sprint/stage cascades) as the
/// final write so observers see fully-applied state.
///
/// One-shot RPC (no streaming, no agent loop) like `PlanningEngine`.
/// Forces a `submit_adaptation` tool call so the response is always
/// structured JSON we can validate; plain prose answers are treated
/// as a `modelDidNotCallTool` error.
///
/// **Outputs the LLM does NOT generate yet** (deferred to a later pass):
/// - Recovery sessions (full block payload generation when the learner
///   is struggling). The proposal carries `next_step.kind ==
///   recommend_recovery` as a flag so a future pass can route into
///   `PlanningEngine` for a remedial session, but no Session row is
///   inserted today.
@DependencyClient
public struct AdaptationEngine: Sendable {
    /// Runs adaptation for a session that just finished. The caller
    /// passes the `Session.ID` only — the engine fetches everything
    /// else (blocks, attempts, sprint/stage/program/profile/concept-
    /// graph context) from the repository so the workspace doesn't
    /// have to thread state through.
    ///
    /// On success the session is marked `completed` and persisted
    /// state is in sync with the returned `AdaptationSummary`.
    public var adapt: @Sendable (
        _ sessionID: Session.ID
    ) async throws -> AdaptationSummary
}

extension AdaptationEngine: DependencyKey {
    public static var liveValue: AdaptationEngine {
        AdaptationEngine(
            adapt: { sessionID in
                @Dependency(\.learningRepository) var repository
                @Dependency(\.chatClient) var chatClient
                @Dependency(\.apiKeyStore) var apiKeyStore

                let model = LanguageModel.defaultPlanningModel
                if model.provider.requiresAPIKey {
                    let key = (try? apiKeyStore.get(provider: model.provider)) ?? nil
                    guard let key, !key.isEmpty else {
                        throw AdaptationEngineError.missingAPIKey
                    }
                }

                let context = try await loadContext(
                    sessionID: sessionID,
                    repository: repository
                )

                let messages = AdaptationPrompt.buildMessages(context: context)
                let toolSpec = ToolSpec(
                    name: "submit_adaptation",
                    description: "Submit the structured session adaptation as JSON. Call exactly once.",
                    inputSchemaJSON: AdaptationPrompt.submitAdaptationSchemaJSON
                )

                var captured: CapturedToolCall?
                var lastStopReason: String?
                do {
                    for try await event in chatClient.stream(
                        messages,
                        model,
                        [toolSpec],
                        .tool(name: "submit_adaptation")
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
                    throw AdaptationEngineError.cancelled
                } catch let error as ChatClientError {
                    if case .missingAPIKey = error {
                        throw AdaptationEngineError.missingAPIKey
                    }
                    throw AdaptationEngineError.network(error.errorDescription ?? error.localizedDescription)
                } catch {
                    throw AdaptationEngineError.network(error.localizedDescription)
                }

                guard let toolCall = captured else {
                    throw AdaptationEngineError.modelDidNotCallTool(stopReason: lastStopReason)
                }

                let proposal: AdaptationProposal
                do {
                    proposal = try JSONDecoder().decode(AdaptationProposal.self, from: toolCall.inputJSON)
                } catch {
                    throw AdaptationEngineError.toolInputInvalidJSON(error.localizedDescription)
                }

                try AdaptationProposalValidator.validate(proposal)

                return try await AdaptationApplier.apply(
                    proposal,
                    sessionID: sessionID,
                    repository: repository
                )
            }
        )
    }

    public static var testValue: AdaptationEngine { AdaptationEngine() }

    private static func loadContext(
        sessionID: Session.ID,
        repository: LearningRepository
    ) async throws -> AdaptationContext {
        guard let session = try await repository.fetchSession(id: sessionID) else {
            throw AdaptationEngineError.sessionNotFound
        }
        guard let sprint = try await repository.fetchSprint(id: session.sprintID) else {
            throw AdaptationEngineError.sessionNotFound
        }
        guard let stage = try await repository.fetchStage(id: sprint.stageID) else {
            throw AdaptationEngineError.sessionNotFound
        }
        let goals = try await repository.fetchAllGoals()
        // Walk programs by goalID — the program lives off LearningGoal,
        // not Stage directly. Iterate goals (small set) until the
        // program FK matches; we already have stage.programID so we
        // just need the goal text + profile for the prompt.
        var programOpt: ProgramBlueprint?
        var matchingGoal: LearningGoal?
        for goal in goals {
            if let candidate = try await repository.fetchProgram(forGoalID: goal.id),
               candidate.id == stage.programID
            {
                programOpt = candidate
                matchingGoal = goal
                break
            }
        }
        guard let program = programOpt, let goal = matchingGoal else {
            throw AdaptationEngineError.sessionNotFound
        }
        let profile = try await repository.ensureCurrentProfile()
        let blocks = try await repository.fetchBlocks(forSessionID: sessionID)
        let attempts = try await repository.fetchLatestAttempts(forSessionID: sessionID)
        let knownConcepts = try await repository.fetchConceptNodes(forProgramID: program.id)
        return AdaptationContext(
            session: session,
            sprint: sprint,
            stage: stage,
            program: program,
            goal: goal,
            profile: profile,
            blocks: blocks,
            attempts: attempts,
            knownConceptTitles: knownConcepts.map(\.title)
        )
    }
}

extension DependencyValues {
    public var adaptationEngine: AdaptationEngine {
        get { self[AdaptationEngine.self] }
        set { self[AdaptationEngine.self] = newValue }
    }
}
