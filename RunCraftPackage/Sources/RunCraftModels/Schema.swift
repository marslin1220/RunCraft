import Dependencies
import Foundation
import SQLiteData

/// Shared between the main app and any future App Group member (e.g. the
/// Today's-session Widget Extension) so they open the same SQLite file.
private let appGroupIdentifier = "group.io.marstudio.RunCraft"

extension DependencyValues {
    public mutating func bootstrapDatabase() throws {
        let database = try SQLiteData.defaultDatabase(path: Self.databasePath)
        try Self.migrate(database)
        defaultDatabase = database
    }

    /// Applies every registered migration to `database`. Shared by
    /// `bootstrapDatabase()` (App Group / Application Support file) and
    /// tests that stand up an in-memory database against this schema.
    public static func migrate(_ database: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        #if DEBUG
            migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1 – initial schema") { db in
            try #sql("""
                CREATE TABLE "raceGoals" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "name" TEXT NOT NULL DEFAULT '',
                  "targetDate" TEXT NOT NULL DEFAULT '',
                  "distanceKm" REAL NOT NULL DEFAULT 0,
                  "currentVDOT" REAL NOT NULL DEFAULT 0,
                  "createdAt" TEXT NOT NULL DEFAULT ''
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "trainingWeeks" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "raceGoalId" TEXT NOT NULL REFERENCES "raceGoals"("id") ON DELETE CASCADE,
                  "weekNumber" INTEGER NOT NULL DEFAULT 1,
                  "phase" TEXT NOT NULL DEFAULT 'base',
                  "startDate" TEXT NOT NULL DEFAULT '',
                  "targetWeeklyKm" REAL NOT NULL DEFAULT 0
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE INDEX "index_trainingWeeks_on_raceGoalId"
                ON "trainingWeeks"("raceGoalId")
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "plannedSessions" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "weekId" TEXT NOT NULL REFERENCES "trainingWeeks"("id") ON DELETE CASCADE,
                  "dayOfWeek" INTEGER NOT NULL DEFAULT 1,
                  "sessionType" TEXT NOT NULL DEFAULT 'rest',
                  "targetDistanceKm" REAL,
                  "targetDurationMin" INTEGER,
                  "targetPaceZone" TEXT,
                  "notes" TEXT NOT NULL DEFAULT ''
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE INDEX "index_plannedSessions_on_weekId"
                ON "plannedSessions"("weekId")
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "completedWorkouts" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "plannedSessionId" TEXT REFERENCES "plannedSessions"("id") ON DELETE SET NULL,
                  "hkWorkoutId" TEXT,
                  "completedAt" TEXT NOT NULL DEFAULT '',
                  "actualDistanceKm" REAL NOT NULL DEFAULT 0,
                  "actualDurationSec" REAL NOT NULL DEFAULT 0,
                  "avgPaceSecPerKm" REAL NOT NULL DEFAULT 0,
                  "paceAchievementRatio" REAL NOT NULL DEFAULT 1
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "workoutTemplates" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "name" TEXT NOT NULL DEFAULT '',
                  "blocksData" TEXT NOT NULL DEFAULT '[]',
                  "createdAt" TEXT NOT NULL DEFAULT '',
                  "updatedAt" TEXT NOT NULL DEFAULT ''
                ) STRICT
                """)
                .execute(db)
        }

        migrator.registerMigration("v2 – vdot snapshots") { db in
            try #sql("""
                CREATE TABLE "vdotSnapshots" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "vdot" REAL NOT NULL DEFAULT 0,
                  "recordedAt" TEXT NOT NULL DEFAULT '',
                  "source" TEXT NOT NULL DEFAULT 'manual'
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE INDEX "index_vdotSnapshots_on_recordedAt"
                ON "vdotSnapshots"("recordedAt")
                """)
                .execute(db)
        }

        migrator.registerMigration("v3 – placeholder race goals") { db in
            try #sql("""
                ALTER TABLE "raceGoals" ADD COLUMN "isPlaceholder" INTEGER NOT NULL DEFAULT 0
                """)
                .execute(db)
        }

        try migrator.migrate(database)
    }

    /// SQLite file location. Prefers the App Group's shared container so a
    /// Widget Extension can open the same database; falls back to the
    /// app's own Application Support directory if the App Groups
    /// entitlement isn't configured yet.
    private static var databasePath: String {
        let directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // SQLite won't create missing parent directories itself, and a
        // freshly-added App Group container may not exist on disk yet.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("RunCraft.db").path
    }
}
