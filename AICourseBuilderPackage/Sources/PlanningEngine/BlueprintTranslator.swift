import Foundation
import LearningModels
import LearningRepository

/// Turns a validated `BlueprintProposal` into the repository's create-call
/// sequence. Ordering: program → all stages → first-stage sprints →
/// first-sprint sessions → first-session blocks. Stage 1 is `inProgress`,
/// stages 2+ are `locked`. Sprint 1 of stage 1 is `inProgress`, sprints
/// 2+ are `upcoming`. All sessions in stage 1 sprint 1 start
/// `notStarted` — the workspace flips them as the learner advances.
enum BlueprintTranslator {
    static func translate(
        _ proposal: BlueprintProposal,
        goalID: LearningGoal.ID,
        repository: LearningRepository
    ) async throws -> ProgramBlueprint.ID {
        do {
            let programID = try await repository.createProgram(
                goalID: goalID,
                summary: proposal.program.summary,
                durationWeeks: proposal.program.durationWeeks
            )

            let sortedStages = proposal.stages.sorted { $0.order < $1.order }
            var stage1ID: Stage.ID?
            for (index, stage) in sortedStages.enumerated() {
                let status = (index == 0) ? Stage.Status.inProgress : Stage.Status.locked
                let stageID = try await repository.createStage(
                    programID: programID,
                    order: index + 1,
                    title: stage.title,
                    intent: stage.intent,
                    status: status
                )
                if index == 0 { stage1ID = stageID }
            }
            guard let stage1ID else { return programID }

            let sortedSprints = proposal.firstStageSprints.sorted { $0.order < $1.order }
            var sprint1ID: Sprint.ID?
            for (index, sprint) in sortedSprints.enumerated() {
                let status = (index == 0) ? Sprint.Status.inProgress : Sprint.Status.upcoming
                let sprintID = try await repository.createSprint(
                    stageID: stage1ID,
                    order: index + 1,
                    title: sprint.title,
                    focus: sprint.focus,
                    status: status
                )
                if index == 0 { sprint1ID = sprintID }
            }
            guard let sprint1ID else { return programID }

            let sortedSessions = proposal.firstSprintSessions.sorted { $0.order < $1.order }
            var session1ID: Session.ID?
            for (index, session) in sortedSessions.enumerated() {
                let sessionID = try await repository.createSession(
                    sprintID: sprint1ID,
                    order: index + 1,
                    title: session.title,
                    objective: session.objective,
                    estimatedMinutes: session.estimatedMinutes,
                    status: Session.Status.notStarted
                )
                if index == 0 { session1ID = sessionID }
            }
            guard let session1ID else { return programID }

            let sortedBlocks = proposal.firstSessionBlocks.sorted { $0.order < $1.order }
            let encoder = JSONEncoder()
            var blocks: [SessionBlock] = []
            for (index, block) in sortedBlocks.enumerated() {
                let payloadData = try encoder.encode(block.payload)
                let payloadJSON = String(decoding: payloadData, as: UTF8.self)
                blocks.append(
                    SessionBlock(
                        id: UUID(),
                        sessionID: session1ID,
                        order: index + 1,
                        kind: block.kind,
                        schemaVersion: block.schemaVersion,
                        payloadJSON: payloadJSON
                    )
                )
            }
            try await repository.createSessionBlocks(blocks)

            return programID
        } catch let error as PlanningEngineError {
            throw error
        } catch {
            throw PlanningEngineError.translationFailed(underlying: error)
        }
    }
}
