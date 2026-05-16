import Dependencies
import SQLiteData

extension DependencyValues {
    public mutating func bootstrapDatabase() throws {
        let database = try SQLiteData.defaultDatabase()
        var migrator = DatabaseMigrator()
        #if DEBUG
            migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1 – initial schema") { db in
            try #sql("""
                CREATE TABLE "raceGoals" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "name" TEXT NOT NULL DEFAULT '',
                  "targetDate" REAL NOT NULL DEFAULT 0,
                  "distanceKm" REAL NOT NULL DEFAULT 0,
                  "currentVDOT" REAL NOT NULL DEFAULT 0,
                  "createdAt" REAL NOT NULL DEFAULT 0
                ) STRICT
                """)
                .execute(db)

            try #sql("""
                CREATE TABLE "trainingWeeks" (
                  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                  "raceGoalId" TEXT NOT NULL REFERENCES "raceGoals"("id") ON DELETE CASCADE,
                  "weekNumber" INTEGER NOT NULL DEFAULT 1,
                  "phase" TEXT NOT NULL DEFAULT 'base',
                  "startDate" REAL NOT NULL DEFAULT 0,
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
                  "completedAt" REAL NOT NULL DEFAULT 0,
                  "actualDistanceKm" REAL NOT NULL DEFAULT 0,
                  "actualDurationSec" REAL NOT NULL DEFAULT 0,
                  "avgPaceSecPerKm" REAL NOT NULL DEFAULT 0,
                  "paceAchievementRatio" REAL NOT NULL DEFAULT 1
                ) STRICT
                """)
                .execute(db)
        }

        try migrator.migrate(database)
        defaultDatabase = database
    }
}
