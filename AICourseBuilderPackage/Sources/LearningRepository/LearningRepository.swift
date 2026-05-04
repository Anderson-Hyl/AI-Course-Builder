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
}
