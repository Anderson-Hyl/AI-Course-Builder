import Dependencies
import Foundation
import LearningModels
import SQLiteData
import StructuredQueries

/// Database-facing façade for learning-state operations. Owns no state of
/// its own — wraps `@Dependency(\.defaultDatabase)` and exposes async CRUD
/// + query methods used by engines (Planning / Evaluation / Adaptation /
/// Tutor) and UI handlers. Single source of mutation truth so engines and
/// views never duplicate `database.write { ... }` setup, and so the
/// `LearningMutationObserver` fans out from one place.
///
/// **Mirrors SlideFlow's `DeckRepository` discipline** — same observer-
/// fires-after-commit pattern, same `Sendable struct` shape, same
/// `@Dependency` wiring.
public struct LearningRepository: Sendable {
    @Dependency(\.defaultDatabase) private var database
    /// Fires after each mutation so the host (app UI, tutor panel, etc.)
    /// can react. Default is a no-op so tests and isolated callers work
    /// without wiring; the AICourseBuilder app overrides it at launch.
    @Dependency(\.learningMutationObserver) private var observer

    public init() {}

    // MARK: - Profiles

    /// Returns the single device-local `LearnerProfile`, creating one with
    /// defaults if none exists. v1 ships single-profile; this method is
    /// the canonical "get me the current learner" entry point. Engines
    /// call this without checking — the profile always exists after the
    /// first invocation.
    @discardableResult
    public func ensureCurrentProfile() async throws -> LearnerProfile {
        try await database.write { db in
            if let existing = try LearnerProfile.all.fetchOne(db) {
                return existing
            }
            let id = UUID()
            try LearnerProfile.insert {
                LearnerProfile.Draft(id: id)
            }
            .execute(db)
            // Re-fetch the row so callers see the trigger-stamped
            // createdAt / updatedAt (the Draft init sees default Date()
            // values, but the trigger overwrites them post-insert).
            guard let row = try LearnerProfile.find(id).fetchOne(db) else {
                throw LearningRepositoryError.profileBootstrapFailed
            }
            return row
        }
    }

    /// Updates the device-local profile in place. Engines and Goal Intake
    /// call this with the partial fields they own — null fields here are
    /// preserved-as-is, not cleared.
    public func updateProfile(
        id: LearnerProfile.ID,
        startingLevel: String? = nil,
        weeklyTimeBudgetHours: Int? = nil,
        learningStyles: Set<String>? = nil,
        targetOutcome: String?? = nil
    ) async throws {
        try await database.write { db in
            try LearnerProfile.find(id).update { row in
                if let startingLevel {
                    row.startingLevel = #bind(startingLevel)
                }
                if let weeklyTimeBudgetHours {
                    row.weeklyTimeBudgetHours = #bind(weeklyTimeBudgetHours)
                }
                if let learningStyles {
                    row.learningStylesJSON = #bind(LearnerProfile.encodeLearningStyles(learningStyles))
                }
                if case .some(let value) = targetOutcome {
                    row.targetOutcome = #bind(value)
                }
            }
            .execute(db)
        }
    }

    // MARK: - Goals

    public func fetchAllGoals() async throws -> [LearningGoal] {
        try await database.read { db in
            try LearningGoal
                .order { $0.createdAt }
                .fetchAll(db)
        }
    }

    /// Returns the active goal if one exists. v1 expects 0 or 1 active
    /// goals; multiple is allowed by the schema but the dashboard surfaces
    /// only the most recent.
    public func fetchActiveGoal() async throws -> LearningGoal? {
        try await database.read { db in
            try LearningGoal
                .where { $0.status.neq(LearningGoal.Status.archived) }
                .order { $0.createdAt.desc() }
                .fetchOne(db)
        }
    }

    @discardableResult
    public func createGoal(
        profileID: LearnerProfile.ID,
        text: String
    ) async throws -> LearningGoal.ID {
        let id = UUID()
        try await database.write { db in
            try LearningGoal.insert {
                LearningGoal.Draft(
                    id: id,
                    profileID: profileID,
                    text: text
                )
            }
            .execute(db)
        }
        await observer.didCreateGoal(id)
        return id
    }

    public func deleteGoal(id: LearningGoal.ID) async throws {
        try await database.write { db in
            try LearningGoal.find(id).delete().execute(db)
        }
        await observer.didDeleteGoal(id)
    }

    // MARK: - Programs

    public func fetchProgram(forGoalID goalID: LearningGoal.ID) async throws -> ProgramBlueprint? {
        try await database.read { db in
            try ProgramBlueprint
                .where { $0.goalID.eq(goalID) }
                .fetchOne(db)
        }
    }

    @discardableResult
    public func createProgram(
        goalID: LearningGoal.ID,
        summary: String,
        durationWeeks: Int? = nil
    ) async throws -> ProgramBlueprint.ID {
        let id = UUID()
        try await database.write { db in
            try ProgramBlueprint.insert {
                ProgramBlueprint.Draft(
                    id: id,
                    goalID: goalID,
                    summary: summary,
                    durationWeeks: durationWeeks
                )
            }
            .execute(db)
        }
        await observer.didCreateProgram(id, goalID: goalID)
        return id
    }

    // MARK: - Stages / Sprints

    @discardableResult
    public func createStage(
        programID: ProgramBlueprint.ID,
        order: Int = 1,
        title: String,
        intent: String,
        status: String = Stage.Status.inProgress
    ) async throws -> Stage.ID {
        let id = UUID()
        try await database.write { db in
            try Stage.insert {
                Stage.Draft(
                    id: id,
                    programID: programID,
                    order: order,
                    title: title,
                    intent: intent,
                    status: status
                )
            }
            .execute(db)
        }
        return id
    }

    @discardableResult
    public func createSprint(
        stageID: Stage.ID,
        order: Int = 1,
        title: String,
        focus: String,
        status: String = Sprint.Status.inProgress
    ) async throws -> Sprint.ID {
        let id = UUID()
        try await database.write { db in
            try Sprint.insert {
                Sprint.Draft(
                    id: id,
                    stageID: stageID,
                    order: order,
                    title: title,
                    focus: focus,
                    status: status
                )
            }
            .execute(db)
        }
        return id
    }

    // MARK: - Sessions

    @discardableResult
    public func createSession(
        sprintID: Sprint.ID,
        order: Int = 1,
        title: String,
        objective: String,
        estimatedMinutes: Int = 15,
        status: String = Session.Status.notStarted
    ) async throws -> Session.ID {
        let id = UUID()
        let programID = try await database.write { db -> ProgramBlueprint.ID in
            try Session.insert {
                Session.Draft(
                    id: id,
                    sprintID: sprintID,
                    order: order,
                    title: title,
                    objective: objective,
                    estimatedMinutes: estimatedMinutes,
                    status: status
                )
            }
            .execute(db)
            return try Self.programID(forSprintID: sprintID, db: db)
        }
        await observer.didChangeSessions(programID: programID)
        return id
    }

    public func fetchSessions(forProgramID programID: ProgramBlueprint.ID) async throws -> [Session] {
        try await database.read { db in
            // Two-step type-safe walk: stages → sprints → sessions, ordered
            // by stage.order, sprint.order, session.order. The demo has
            // exactly one stage / one sprint, so this stays cheap; when
            // the planner produces more we can swap in a single-#sql
            // join with a `@Selection` projection.
            let stages = try Stage
                .where { $0.programID.eq(programID) }
                .order { $0.order }
                .fetchAll(db)
            var ordered: [Session] = []
            for stage in stages {
                let sprints = try Sprint
                    .where { $0.stageID.eq(stage.id) }
                    .order { $0.order }
                    .fetchAll(db)
                for sprint in sprints {
                    let sessions = try Session
                        .where { $0.sprintID.eq(sprint.id) }
                        .order { $0.order }
                        .fetchAll(db)
                    ordered.append(contentsOf: sessions)
                }
            }
            return ordered
        }
    }

    public func fetchSession(id: Session.ID) async throws -> Session? {
        try await database.read { db in
            try Session.find(id).fetchOne(db)
        }
    }

    public func fetchStage(id: Stage.ID) async throws -> Stage? {
        try await database.read { db in
            try Stage.find(id).fetchOne(db)
        }
    }

    public func fetchSprint(id: Sprint.ID) async throws -> Sprint? {
        try await database.read { db in
            try Sprint.find(id).fetchOne(db)
        }
    }

    public func fetchStages(forProgramID programID: ProgramBlueprint.ID) async throws -> [Stage] {
        try await database.read { db in
            try Stage
                .where { $0.programID.eq(programID) }
                .order { $0.order }
                .fetchAll(db)
        }
    }

    public func fetchSprints(forStageID stageID: Stage.ID) async throws -> [Sprint] {
        try await database.read { db in
            try Sprint
                .where { $0.stageID.eq(stageID) }
                .order { $0.order }
                .fetchAll(db)
        }
    }

    public func fetchSessions(forSprintID sprintID: Sprint.ID) async throws -> [Session] {
        try await database.read { db in
            try Session
                .where { $0.sprintID.eq(sprintID) }
                .order { $0.order }
                .fetchAll(db)
        }
    }

    /// Updates a session's status. Fires `didChangeSessions` always (so
    /// progress rails repaint) and `didCompleteSession` when the new
    /// status is `Session.Status.completed` so the host can drive the
    /// post-session adaptation flow off a single hook. The transition
    /// to `completed` is the load-bearing one for `AdaptationEngine`;
    /// the other status values are useful for `inProgress` / `deferred`
    /// tracking but don't have dedicated hooks yet.
    public func updateSessionStatus(
        id: Session.ID,
        status: String
    ) async throws {
        let programID = try await database.write { db -> ProgramBlueprint.ID in
            try Session.find(id).update { row in
                row.status = #bind(status)
            }
            .execute(db)
            return try Self.programID(forSessionID: id, db: db)
        }
        await observer.didChangeSessions(programID: programID)
        if status == Session.Status.completed {
            await observer.didCompleteSession(id, programID: programID)
        }
    }

    /// Updates a sprint's status. Fires `didChangeSessions` since sprint
    /// status drives the same Course Home / Program Map repaint as a
    /// session change. `AdaptationEngine` calls this after marking the
    /// last session in a sprint complete.
    public func updateSprintStatus(
        id: Sprint.ID,
        status: String
    ) async throws {
        let programID = try await database.write { db -> ProgramBlueprint.ID in
            try Sprint.find(id).update { row in
                row.status = #bind(status)
            }
            .execute(db)
            return try Self.programID(forSprintID: id, db: db)
        }
        await observer.didChangeSessions(programID: programID)
    }

    /// Updates a stage's status. Fires `didChangeSessions` so Program
    /// Map repaints. `AdaptationEngine` calls this after the last sprint
    /// in a stage completes; the next stage transitions from `locked`
    /// to `inProgress` in the same flow.
    public func updateStageStatus(
        id: Stage.ID,
        status: String
    ) async throws {
        let programID = try await database.write { db -> ProgramBlueprint.ID in
            guard let stage = try Stage.find(id).fetchOne(db) else {
                throw LearningRepositoryError.stageNotFound(id)
            }
            try Stage.find(id).update { row in
                row.status = #bind(status)
            }
            .execute(db)
            return stage.programID
        }
        await observer.didChangeSessions(programID: programID)
    }

    // MARK: - Session blocks

    /// Inserts blocks in `order`-ascending order so the first row's
    /// trigger-stamped order lands at 1 (no siblings yet) and subsequent
    /// rows bypass the trigger entirely. See Schema.swift's INSERT-trigger
    /// note: the trigger only fires `WHEN new.order = 1`, so out-of-order
    /// insertion of the order=1 row would re-stamp it to MAX+1.
    @discardableResult
    public func createSessionBlocks(_ blocks: [SessionBlock]) async throws -> [SessionBlock.ID] {
        let sorted = blocks.sorted { $0.order < $1.order }
        let touchedProgramIDs: Set<ProgramBlueprint.ID> = try await database.write { db in
            for block in sorted {
                try SessionBlock.insert {
                    SessionBlock.Draft(
                        id: block.id,
                        sessionID: block.sessionID,
                        order: block.order,
                        kind: block.kind,
                        schemaVersion: block.schemaVersion,
                        payloadJSON: block.payloadJSON
                    )
                }
                .execute(db)
            }
            var programs: Set<ProgramBlueprint.ID> = []
            for sessionID in Set(sorted.map(\.sessionID)) {
                if let programID = try? Self.programID(forSessionID: sessionID, db: db) {
                    programs.insert(programID)
                }
            }
            return programs
        }
        for programID in touchedProgramIDs {
            await observer.didChangeSessions(programID: programID)
        }
        return sorted.map(\.id)
    }

    public func fetchBlocks(forSessionID sessionID: Session.ID) async throws -> [SessionBlock] {
        try await database.read { db in
            try SessionBlock
                .where { $0.sessionID.eq(sessionID) }
                .order { $0.order }
                .fetchAll(db)
        }
    }

    // MARK: - Attempts

    /// Records a learner attempt at a block. `inputJSON` always set;
    /// `resultJSON` is set when the evaluator has a verdict (today: only
    /// `multiple_choice`, evaluated heuristically against `correct_index`).
    /// `scoredAt` mirrors `resultJSON` presence — a non-nil result is a
    /// scored attempt, nil is pending.
    @discardableResult
    public func recordAttempt(
        blockID: SessionBlock.ID,
        kind: String,
        inputJSON: String,
        resultJSON: String? = nil
    ) async throws -> Attempt.ID {
        let id = UUID()
        try await database.write { db in
            try Attempt.insert {
                Attempt.Draft(
                    id: id,
                    blockID: blockID,
                    kind: kind,
                    inputJSON: inputJSON,
                    resultJSON: resultJSON,
                    scoredAt: resultJSON != nil ? Date() : nil
                )
            }
            .execute(db)
        }
        await observer.didRecordAttempt(id, blockID: blockID)
        return id
    }

    /// Latest-by-`createdAt` attempt for a block, or nil if the learner
    /// hasn't submitted yet. Session Workspace calls this on appear so
    /// re-entering a session restores the prior selection + verdict
    /// instead of looking pristine.
    public func fetchLatestAttempt(forBlockID blockID: SessionBlock.ID) async throws -> Attempt? {
        try await database.read { db in
            try Attempt
                .where { $0.blockID.eq(blockID) }
                .order { $0.createdAt.desc() }
                .fetchOne(db)
        }
    }

    /// Latest attempt per block in a session, keyed by `SessionBlock.ID`.
    /// Single round-trip: pulls every attempt for any block in the
    /// session via `IN`-subquery, then collapses to latest-per-block in
    /// memory. Cheap at session scale (≤~30 blocks × small attempt count).
    public func fetchLatestAttempts(
        forSessionID sessionID: Session.ID
    ) async throws -> [SessionBlock.ID: Attempt] {
        try await database.read { db in
            let attempts = try Attempt
                .where { $0.blockID.in(SessionBlock.where { $0.sessionID.eq(sessionID) }.select(\.id)) }
                .order { $0.createdAt }
                .fetchAll(db)
            // `order(by: createdAt)` ascending + `uniquingKeysWith: latest`
            // keeps the most recent attempt per block. If the same block
            // has multiple attempts (resubmits), the trailing one wins.
            return Dictionary(attempts.map { ($0.blockID, $0) }, uniquingKeysWith: { _, latest in latest })
        }
    }

    // MARK: - Concept graph

    public func fetchConceptNodes(
        forProgramID programID: ProgramBlueprint.ID
    ) async throws -> [ConceptNode] {
        try await database.read { db in
            try ConceptNode
                .where { $0.programID.eq(programID) }
                .order { $0.createdAt }
                .fetchAll(db)
        }
    }

    /// Idempotent concept creation keyed on title within a program. Returns
    /// the existing concept's id if one already exists with the same case-
    /// insensitive title; otherwise inserts a new node. Used by
    /// `AdaptationEngine` to grow the concept graph as the LLM identifies
    /// topics across sessions — saves the planner from having to seed every
    /// concept upfront. Title comparison is case-insensitive but the stored
    /// title preserves the LLM's casing for display.
    @discardableResult
    public func findOrCreateConceptNode(
        programID: ProgramBlueprint.ID,
        title: String,
        prerequisites: [UUID] = []
    ) async throws -> ConceptNode.ID {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmedTitle.lowercased()
        let prerequisitesJSON = ConceptNode.encodePrerequisites(prerequisites)
        let result = try await database.write { db -> (id: UUID, didInsert: Bool) in
            // Case-insensitive match in app code rather than via #sql LIKE
            // — the program-scoped concept set is small (tens to low
            // hundreds of rows) and StructuredQueries doesn't expose a
            // portable lower() helper here.
            let siblings = try ConceptNode
                .where { $0.programID.eq(programID) }
                .fetchAll(db)
            if let existing = siblings.first(where: {
                $0.title.lowercased() == normalized
            }) {
                return (existing.id, false)
            }
            let newID = UUID()
            try ConceptNode.insert {
                ConceptNode.Draft(
                    id: newID,
                    programID: programID,
                    title: trimmedTitle,
                    prerequisitesJSON: prerequisitesJSON
                )
            }
            .execute(db)
            return (newID, true)
        }
        if result.didInsert {
            await observer.didChangeMastery(programID: programID)
        }
        return result.id
    }

    // MARK: - Mastery state

    public func fetchMasteryStates(
        forProgramID programID: ProgramBlueprint.ID
    ) async throws -> [MasteryState] {
        try await database.read { db in
            let conceptIDs = try ConceptNode
                .where { $0.programID.eq(programID) }
                .select(\.id)
                .fetchAll(db)
            guard !conceptIDs.isEmpty else { return [] }
            return try MasteryState
                .where { $0.conceptID.in(conceptIDs) }
                .fetchAll(db)
        }
    }

    public func fetchMasteryState(
        forConceptID conceptID: ConceptNode.ID
    ) async throws -> MasteryState? {
        try await database.read { db in
            try MasteryState
                .where { $0.conceptID.eq(conceptID) }
                .fetchOne(db)
        }
    }

    /// Upsert by `conceptID`: updates the existing row in place if one
    /// exists, otherwise inserts a fresh row. Fires `didChangeMastery`
    /// once per call regardless of which branch executed. `level` and
    /// `confidence` are clamped to `[0, 1]` defensively — the LLM
    /// occasionally returns slightly out-of-range floats and the schema
    /// has no CHECK constraint here.
    public func upsertMasteryState(
        conceptID: ConceptNode.ID,
        level: Double,
        confidence: Double,
        lastReviewedAt: Date?,
        nextReviewAt: Date?
    ) async throws {
        let clampedLevel = max(0.0, min(1.0, level))
        let clampedConfidence = max(0.0, min(1.0, confidence))
        let programID = try await database.write { db -> ProgramBlueprint.ID? in
            guard let concept = try ConceptNode.find(conceptID).fetchOne(db) else {
                return nil
            }
            if let existing = try MasteryState.where({ $0.conceptID.eq(conceptID) }).fetchOne(db) {
                try MasteryState.find(existing.id).update { row in
                    row.level = #bind(clampedLevel)
                    row.confidence = #bind(clampedConfidence)
                    if let lastReviewedAt {
                        row.lastReviewedAt = #bind(lastReviewedAt)
                    }
                    if let nextReviewAt {
                        row.nextReviewAt = #bind(nextReviewAt)
                    }
                }
                .execute(db)
            } else {
                try MasteryState.insert {
                    MasteryState.Draft(
                        id: UUID(),
                        conceptID: conceptID,
                        level: clampedLevel,
                        confidence: clampedConfidence,
                        lastReviewedAt: lastReviewedAt,
                        nextReviewAt: nextReviewAt
                    )
                }
                .execute(db)
            }
            return concept.programID
        }
        if let programID {
            await observer.didChangeMastery(programID: programID)
        }
    }

    // MARK: - Review queue

    public func fetchReviewItems(
        forProgramID programID: ProgramBlueprint.ID,
        dueBefore: Date? = nil
    ) async throws -> [ReviewItem] {
        try await database.read { db in
            let conceptIDs = try ConceptNode
                .where { $0.programID.eq(programID) }
                .select(\.id)
                .fetchAll(db)
            guard !conceptIDs.isEmpty else { return [] }
            if let cutoff = dueBefore {
                return try ReviewItem
                    .where { $0.conceptID.in(conceptIDs) }
                    .where { $0.dueAt.lte(cutoff) }
                    .order { $0.dueAt }
                    .fetchAll(db)
            }
            return try ReviewItem
                .where { $0.conceptID.in(conceptIDs) }
                .order { $0.dueAt }
                .fetchAll(db)
        }
    }

    @discardableResult
    public func createReviewItem(
        conceptID: ConceptNode.ID,
        dueAt: Date,
        intervalDays: Int,
        lapseCount: Int = 0
    ) async throws -> ReviewItem.ID {
        let id = UUID()
        let programID = try await database.write { db -> ProgramBlueprint.ID? in
            guard let concept = try ConceptNode.find(conceptID).fetchOne(db) else {
                return nil
            }
            try ReviewItem.insert {
                ReviewItem.Draft(
                    id: id,
                    conceptID: conceptID,
                    dueAt: dueAt,
                    intervalDays: intervalDays,
                    lapseCount: lapseCount
                )
            }
            .execute(db)
            return concept.programID
        }
        if let programID {
            await observer.didChangeReviewQueue(programID: programID)
        }
        return id
    }

    // MARK: - Artifacts

    /// Records a learner-output artifact (or an engine-generated reflection
    /// like a `session_adaptation` summary). Free-form `kind` + JSON
    /// payload — see `Artifact.Kind` for the discriminator constants.
    /// No observer hook fires today: nothing in the app currently
    /// subscribes to artifact writes. Add one when Review Vault wires in.
    @discardableResult
    public func recordArtifact(
        sessionID: Session.ID? = nil,
        attemptID: Attempt.ID? = nil,
        kind: String,
        contentJSON: String
    ) async throws -> Artifact.ID {
        let id = UUID()
        try await database.write { db in
            try Artifact.insert {
                Artifact.Draft(
                    id: id,
                    sessionID: sessionID,
                    attemptID: attemptID,
                    kind: kind,
                    contentJSON: contentJSON
                )
            }
            .execute(db)
        }
        return id
    }

    public func fetchArtifacts(forSessionID sessionID: Session.ID) async throws -> [Artifact] {
        try await database.read { db in
            try Artifact
                .where { $0.sessionID.eq(sessionID) }
                .order { $0.createdAt }
                .fetchAll(db)
        }
    }

    // MARK: - Demo seed

    /// Idempotent: returns the existing program for `goalID` if one
    /// exists, otherwise builds the Haskell demo blueprint (1 program →
    /// 1 stage → 1 sprint → 1 session → 10 blocks) by calling the
    /// underlying mutators so observer hooks fire uniformly. The block
    /// payloads come from `DemoBlueprint.blocks(forSession:)` — a
    /// production-side mirror of `LessonRendering.Fixtures.haskellSessionBlocks`
    /// that doesn't pull SwiftUI into this module.
    @discardableResult
    public func installDemoProgram(goalID: LearningGoal.ID) async throws -> ProgramBlueprint.ID {
        if let existing = try await fetchProgram(forGoalID: goalID) {
            return existing.id
        }
        let programID = try await createProgram(
            goalID: goalID,
            summary: DemoBlueprint.summary
        )
        let stageID = try await createStage(
            programID: programID,
            title: DemoBlueprint.stageTitle,
            intent: DemoBlueprint.stageIntent,
            status: Stage.Status.inProgress
        )
        let sprintID = try await createSprint(
            stageID: stageID,
            title: DemoBlueprint.sprintTitle,
            focus: DemoBlueprint.sprintFocus,
            status: Sprint.Status.inProgress
        )
        let sessionID = try await createSession(
            sprintID: sprintID,
            title: DemoBlueprint.sessionTitle,
            objective: DemoBlueprint.sessionObjective,
            estimatedMinutes: DemoBlueprint.sessionEstimatedMinutes
        )
        try await createSessionBlocks(
            DemoBlueprint.blocks(forSession: sessionID)
        )
        return programID
    }

    // MARK: - Internal helpers

    /// Walks sprint → stage → program inside an open transaction so
    /// observer hook payloads stay consistent with the row that just
    /// committed. Throws `LearningRepositoryError.sprintNotFound` /
    /// `.stageNotFound` if either parent row is missing — should only
    /// happen if a caller hands in a stale or fabricated FK.
    fileprivate static func programID(
        forSprintID sprintID: Sprint.ID,
        db: Database
    ) throws -> ProgramBlueprint.ID {
        guard let sprint = try Sprint.find(sprintID).fetchOne(db) else {
            throw LearningRepositoryError.sprintNotFound(sprintID)
        }
        guard let stage = try Stage.find(sprint.stageID).fetchOne(db) else {
            throw LearningRepositoryError.stageNotFound(sprint.stageID)
        }
        return stage.programID
    }

    fileprivate static func programID(
        forSessionID sessionID: Session.ID,
        db: Database
    ) throws -> ProgramBlueprint.ID {
        guard let session = try Session.find(sessionID).fetchOne(db) else {
            throw LearningRepositoryError.sessionNotFound(sessionID)
        }
        return try programID(forSprintID: session.sprintID, db: db)
    }
}

/// Errors thrown by `LearningRepository`. Callers don't switch on these
/// today — they propagate to the UI as a generic "Couldn't save" toast —
/// but defining them as a dedicated type keeps the seam clean for when a
/// reducer wants to recover from a specific failure (e.g. retry after a
/// transient SQLite lock).
public enum LearningRepositoryError: Error, Sendable {
    case profileBootstrapFailed
    case goalNotFound(LearningGoal.ID)
    case programNotFound(ProgramBlueprint.ID)
    case sprintNotFound(Sprint.ID)
    case stageNotFound(Stage.ID)
    case sessionNotFound(Session.ID)
}
