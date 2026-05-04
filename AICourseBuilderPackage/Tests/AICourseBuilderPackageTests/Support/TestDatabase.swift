import Dependencies
import Foundation
import LearningModels
import SQLiteData

/// Build an in-memory SQLite database populated with the same schema as
/// production `bootstrapDatabase()`. No seed rows — tests insert exactly
/// what they need via `LearningRepository`. Returns a `DatabaseWriter`
/// ready to be assigned to `defaultDatabase` via `withDependencies`.
///
/// **Schema is duplicated by hand** from `LearningDatabase/Schema.swift`.
/// Mirrors SlideFlow's discipline (`SlideFlowPackage/Tests/AppFeatureTests/
/// Support/TestDatabase.swift`): the production migrator runs against the
/// user's on-disk DB and pulls in DEBUG schema-erase + the future SyncEngine
/// slot, both of which we don't want in tests. Keep these `CREATE TABLE`
/// statements byte-identical to production — when production schema
/// changes, this file changes too.
@MainActor
func makeTestDatabase() throws -> any DatabaseWriter {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    configuration.prepareDatabase { db in
        db.add(function: $uuid)
    }

    let database = try SQLiteData.defaultDatabase(
        path: ":memory:",
        configuration: configuration
    )

    var migrator = DatabaseMigrator()
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
            """).execute(db)

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
            """).execute(db)

        try #sql("""
            CREATE TABLE "programBlueprints" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "goalID" TEXT NOT NULL REFERENCES "learningGoals"("id") ON DELETE CASCADE,
              "summary" TEXT NOT NULL DEFAULT '',
              "durationWeeks" INTEGER,
              "createdAt" TEXT,
              "updatedAt" TEXT
            ) STRICT
            """).execute(db)

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
            """).execute(db)

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
            """).execute(db)

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
            """).execute(db)

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
            """).execute(db)

        try #sql("""
            CREATE TABLE "conceptNodes" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "programID" TEXT NOT NULL REFERENCES "programBlueprints"("id") ON DELETE CASCADE,
              "title" TEXT NOT NULL DEFAULT '',
              "prerequisitesJSON" TEXT NOT NULL DEFAULT '[]',
              "createdAt" TEXT
            ) STRICT
            """).execute(db)

        try #sql("""
            CREATE TABLE "competencies" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "programID" TEXT NOT NULL REFERENCES "programBlueprints"("id") ON DELETE CASCADE,
              "title" TEXT NOT NULL DEFAULT '',
              "competencyDescription" TEXT,
              "createdAt" TEXT
            ) STRICT
            """).execute(db)

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
            """).execute(db)

        try #sql("""
            CREATE TABLE "artifacts" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "sessionID" TEXT REFERENCES "sessions"("id") ON DELETE CASCADE,
              "attemptID" TEXT REFERENCES "attempts"("id") ON DELETE CASCADE,
              "kind" TEXT NOT NULL DEFAULT '',
              "contentJSON" TEXT NOT NULL DEFAULT '{}',
              "createdAt" TEXT
            ) STRICT
            """).execute(db)

        try #sql("""
            CREATE TABLE "masteryStates" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "conceptID" TEXT NOT NULL REFERENCES "conceptNodes"("id") ON DELETE CASCADE,
              "level" REAL NOT NULL DEFAULT 0,
              "confidence" REAL NOT NULL DEFAULT 0,
              "lastReviewedAt" TEXT,
              "nextReviewAt" TEXT
            ) STRICT
            """).execute(db)

        try #sql("""
            CREATE TABLE "reviewItems" (
              "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
              "conceptID" TEXT NOT NULL REFERENCES "conceptNodes"("id") ON DELETE CASCADE,
              "dueAt" TEXT NOT NULL DEFAULT (datetime('now')),
              "intervalDays" INTEGER NOT NULL DEFAULT 1,
              "lapseCount" INTEGER NOT NULL DEFAULT 0,
              "createdAt" TEXT
            ) STRICT
            """).execute(db)

        try #sql("""
            CREATE INDEX "index_attempts_on_blockID" ON "attempts"("blockID")
            """).execute(db)
        try #sql("""
            CREATE INDEX "index_sessionBlocks_on_sessionID" ON "sessionBlocks"("sessionID")
            """).execute(db)
        try #sql("""
            CREATE INDEX "index_sessions_on_sprintID" ON "sessions"("sprintID")
            """).execute(db)
        try #sql("""
            CREATE INDEX "index_sprints_on_stageID" ON "sprints"("stageID")
            """).execute(db)
        try #sql("""
            CREATE INDEX "index_stages_on_programID" ON "stages"("programID")
            """).execute(db)
    }

    try migrator.migrate(database)
    return database
}

@DatabaseFunction
private func uuid() -> String {
    UUID().uuidString.lowercased()
}
