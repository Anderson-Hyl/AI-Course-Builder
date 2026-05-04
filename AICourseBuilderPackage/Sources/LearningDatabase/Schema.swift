import Dependencies
import Foundation
import LearningModels
import os
import SQLiteData

private let dbLog = Logger(subsystem: "com.aicoursebuilder", category: "database")

extension DependencyValues {
    /// Initial bootstrap for the local SQLite store. Runs once per app
    /// launch from `prepareDependencies { try $0.bootstrapDatabase() }`.
    /// Creates the connection, registers the `uuid()` SQL function (so
    /// `DEFAULT (uuid())` columns work), runs migrations, attaches
    /// auto-`createdAt`/`updatedAt` triggers, and wires the order-
    /// compaction triggers on `sessionBlocks`.
    ///
    /// **Mirrors SlideFlow's `bootstrapDatabase` discipline** — same
    /// pattern, AI-Course-Builder schema. CloudKit `SyncEngine`
    /// attachment is deliberately deferred until the local-first loop is
    /// solid; the wiring slot is documented at the bottom of this file.
    public mutating func bootstrapDatabase() throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.prepareDatabase { db in
            db.add(function: $uuid)
        }

        let database = try SQLiteData.defaultDatabase(configuration: configuration)

        var migrator = DatabaseMigrator()
        #if DEBUG
        // Schema edits wipe the local DB on next DEBUG launch so dev
        // iteration doesn't accumulate broken-shape rows. Tell the user
        // to expect a one-time wipe after a `CREATE TABLE` change.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // Schema graph (cascade arrows = ON DELETE CASCADE):
        //   learnerProfile  → learningGoal → programBlueprint
        //                                      → stage → sprint → session → sessionBlock → attempt
        //                                      → conceptNode → masteryState, reviewItem
        //                                      → competency
        //                     plus artifact (sessionID? + attemptID? — both CASCADE on parent delete)
        //
        // STRICT typing on every table so column types are enforced —
        // catches drift the moment a write tries to land the wrong shape.
        migrator.registerMigration("Create initial schema") { db in
            try #sql("""
                CREATE TABLE "learnerProfiles" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "displayName" TEXT,
                  "startingLevel" TEXT NOT NULL DEFAULT 'beginner',
                  "weeklyTimeBudgetHours" INTEGER NOT NULL DEFAULT 5,
                  "learningStylesJSON" TEXT NOT NULL DEFAULT '[]',
                  "targetOutcome" TEXT,
                  "createdAt" TEXT,
                  "updatedAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "learningGoals" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "profileID" TEXT NOT NULL REFERENCES "learnerProfiles"("id") ON DELETE CASCADE,
                  "text" TEXT NOT NULL DEFAULT '',
                  "normalizedTopic" TEXT,
                  "status" TEXT NOT NULL DEFAULT 'draft',
                  "createdAt" TEXT,
                  "updatedAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "programBlueprints" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "goalID" TEXT NOT NULL REFERENCES "learningGoals"("id") ON DELETE CASCADE,
                  "summary" TEXT NOT NULL DEFAULT '',
                  "durationWeeks" INTEGER,
                  "createdAt" TEXT,
                  "updatedAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "stages" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "programID" TEXT NOT NULL REFERENCES "programBlueprints"("id") ON DELETE CASCADE,
                  "order" INTEGER NOT NULL DEFAULT 1,
                  "title" TEXT NOT NULL DEFAULT '',
                  "intent" TEXT NOT NULL DEFAULT '',
                  "status" TEXT NOT NULL DEFAULT 'locked',
                  "createdAt" TEXT,
                  "updatedAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "sprints" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "stageID" TEXT NOT NULL REFERENCES "stages"("id") ON DELETE CASCADE,
                  "order" INTEGER NOT NULL DEFAULT 1,
                  "title" TEXT NOT NULL DEFAULT '',
                  "focus" TEXT NOT NULL DEFAULT '',
                  "status" TEXT NOT NULL DEFAULT 'upcoming',
                  "createdAt" TEXT,
                  "updatedAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "sessions" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "sprintID" TEXT NOT NULL REFERENCES "sprints"("id") ON DELETE CASCADE,
                  "order" INTEGER NOT NULL DEFAULT 1,
                  "title" TEXT NOT NULL DEFAULT '',
                  "objective" TEXT NOT NULL DEFAULT '',
                  "estimatedMinutes" INTEGER NOT NULL DEFAULT 15,
                  "status" TEXT NOT NULL DEFAULT 'not_started',
                  "createdAt" TEXT,
                  "updatedAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "sessionBlocks" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "sessionID" TEXT NOT NULL REFERENCES "sessions"("id") ON DELETE CASCADE,
                  "order" INTEGER NOT NULL DEFAULT 1,
                  "kind" TEXT NOT NULL DEFAULT 'concept',
                  "schemaVersion" INTEGER NOT NULL DEFAULT 1,
                  "payloadJSON" TEXT NOT NULL DEFAULT '{}',
                  "createdAt" TEXT,
                  "updatedAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "conceptNodes" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "programID" TEXT NOT NULL REFERENCES "programBlueprints"("id") ON DELETE CASCADE,
                  "title" TEXT NOT NULL DEFAULT '',
                  "prerequisitesJSON" TEXT NOT NULL DEFAULT '[]',
                  "createdAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "competencies" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "programID" TEXT NOT NULL REFERENCES "programBlueprints"("id") ON DELETE CASCADE,
                  "title" TEXT NOT NULL DEFAULT '',
                  "competencyDescription" TEXT,
                  "createdAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "attempts" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "blockID" TEXT NOT NULL REFERENCES "sessionBlocks"("id") ON DELETE CASCADE,
                  "kind" TEXT NOT NULL DEFAULT '',
                  "inputJSON" TEXT NOT NULL DEFAULT '{}',
                  "resultJSON" TEXT,
                  "scoredAt" TEXT,
                  "createdAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "artifacts" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "sessionID" TEXT REFERENCES "sessions"("id") ON DELETE CASCADE,
                  "attemptID" TEXT REFERENCES "attempts"("id") ON DELETE CASCADE,
                  "kind" TEXT NOT NULL DEFAULT '',
                  "contentJSON" TEXT NOT NULL DEFAULT '{}',
                  "createdAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "masteryStates" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "conceptID" TEXT NOT NULL REFERENCES "conceptNodes"("id") ON DELETE CASCADE,
                  "level" REAL NOT NULL DEFAULT 0,
                  "confidence" REAL NOT NULL DEFAULT 0,
                  "lastReviewedAt" TEXT,
                  "nextReviewAt" TEXT
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "reviewItems" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "conceptID" TEXT NOT NULL REFERENCES "conceptNodes"("id") ON DELETE CASCADE,
                  "dueAt" TEXT NOT NULL DEFAULT (datetime('now')),
                  "intervalDays" INTEGER NOT NULL DEFAULT 1,
                  "lapseCount" INTEGER NOT NULL DEFAULT 0,
                  "createdAt" TEXT
                ) STRICT
                """)
                .execute(db)

            // FK lookup indexes — all FK columns get an index so cascade
            // deletes don't full-scan and JOINs stay cheap once data
            // grows past a single program's worth of rows.
            try #sql("""
                CREATE INDEX "index_learningGoals_on_profileID" ON "learningGoals"("profileID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_programBlueprints_on_goalID" ON "programBlueprints"("goalID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_stages_on_programID" ON "stages"("programID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_sprints_on_stageID" ON "sprints"("stageID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_sessions_on_sprintID" ON "sessions"("sprintID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_sessionBlocks_on_sessionID" ON "sessionBlocks"("sessionID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_conceptNodes_on_programID" ON "conceptNodes"("programID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_competencies_on_programID" ON "competencies"("programID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_attempts_on_blockID" ON "attempts"("blockID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_artifacts_on_sessionID" ON "artifacts"("sessionID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_artifacts_on_attemptID" ON "artifacts"("attemptID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_masteryStates_on_conceptID" ON "masteryStates"("conceptID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_reviewItems_on_conceptID" ON "reviewItems"("conceptID")
                """).execute(db)
            try #sql("""
                CREATE INDEX "index_reviewItems_on_dueAt" ON "reviewItems"("dueAt")
                """).execute(db)
        }

        try migrator.migrate(database)

        try database.write { db in
            // createdAt / updatedAt auto-stamp triggers. Same shape as
            // SlideFlow's — every row gets created/updated timestamps the
            // moment a write hits, no caller plumbing.
            try LearnerProfile.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try LearnerProfile.createTemporaryTrigger(after: .insert(touch: \.updatedAt)).execute(db)
            try LearnerProfile.createTemporaryTrigger(after: .update(touch: \.updatedAt)).execute(db)

            try LearningGoal.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try LearningGoal.createTemporaryTrigger(after: .insert(touch: \.updatedAt)).execute(db)
            try LearningGoal.createTemporaryTrigger(after: .update(touch: \.updatedAt)).execute(db)

            try ProgramBlueprint.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try ProgramBlueprint.createTemporaryTrigger(after: .insert(touch: \.updatedAt)).execute(db)
            try ProgramBlueprint.createTemporaryTrigger(after: .update(touch: \.updatedAt)).execute(db)

            try Stage.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try Stage.createTemporaryTrigger(after: .insert(touch: \.updatedAt)).execute(db)
            try Stage.createTemporaryTrigger(after: .update(touch: \.updatedAt)).execute(db)

            try Sprint.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try Sprint.createTemporaryTrigger(after: .insert(touch: \.updatedAt)).execute(db)
            try Sprint.createTemporaryTrigger(after: .update(touch: \.updatedAt)).execute(db)

            try Session.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try Session.createTemporaryTrigger(after: .insert(touch: \.updatedAt)).execute(db)
            try Session.createTemporaryTrigger(after: .update(touch: \.updatedAt)).execute(db)

            try SessionBlock.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try SessionBlock.createTemporaryTrigger(after: .insert(touch: \.updatedAt)).execute(db)
            try SessionBlock.createTemporaryTrigger(after: .update(touch: \.updatedAt)).execute(db)

            try ConceptNode.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try Competency.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try Attempt.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try Artifact.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)
            try ReviewItem.createTemporaryTrigger(after: .insert(touch: \.createdAt)).execute(db)

            // Auto-assign session-block order on insert: when a block is
            // inserted with the default order (1) and there are already
            // siblings in the same session, bump it to MAX(order) + 1.
            // Same pattern as SlideFlow's `slideInstances` order trigger.
            try SessionBlock.createTemporaryTrigger(
                after: .insert(
                    forEachRow: { new in
                        SessionBlock.find(new.id).update { row in
                            row.order = #sql("""
                                COALESCE((
                                  SELECT MAX("order") + 1
                                  FROM "sessionBlocks"
                                  WHERE "sessionID" = \(new.sessionID)
                                  AND "id" != \(new.id)
                                ), 1)
                                """, as: Int.self)
                        }
                    },
                    when: { new in
                        new.order.eq(1)
                    }
                )
            )
            .execute(db)

            // Compact session-block order on delete so badges stay
            // 01, 02, 03 contiguous. Cascade-deletes (parent session
            // removed) cause this trigger to fire once per surviving
            // sibling — wasted work, but the WHERE matches zero rows
            // so it stays correct.
            try SessionBlock.createTemporaryTrigger(
                after: .delete(
                    forEachRow: { old in
                        SessionBlock
                            .where { $0.sessionID.eq(old.sessionID) }
                            .where { $0.order.gt(old.order) }
                            .update { row in
                                row.order = #sql("\"order\" - 1", as: Int.self)
                            }
                    }
                )
            )
            .execute(db)
        }

        defaultDatabase = database

        // CloudKit `SyncEngine` attachment goes here in a later pass.
        // Mirror SlideFlow's pattern: build a `SyncEngine(for: database,
        // tables: ..., containerIdentifier: ...)`, assign to
        // `defaultSyncEngine`, log success/failure non-fatally so iCloud-
        // unavailable dev launches stay usable. Decide which tables sync
        // (programs + sessions + blocks definitely; attempts + mastery
        // probably; chat history almost certainly device-local) before
        // wiring.
        dbLog.info("LearningDatabase bootstrap complete")
    }
}

@DatabaseFunction
private func uuid() -> String {
    UUID().uuidString.lowercased()
}
