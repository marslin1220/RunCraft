import AppIntents
import Dependencies
import Foundation
import RunCraftModels
import SQLiteData
import VDOTEngine

/// Resolves "today's session" from the local SQLiteData database.
///
/// Read-only — used by `WhatIsTodaysTrainingIntent` to surface today's
/// session in Siri / Spotlight / Apple Intelligence without launching
/// the UI.
public struct TodaySessionQuery: EntityQuery {

    public init() {}

    public func entities(for identifiers: [String]) async throws -> [TodaySessionEntity] {
        let entity: TodaySessionEntity? = try await loadToday()
        guard let entity else { return [] }
        return identifiers.contains(entity.id) ? [entity] : []
    }

    public func suggestedEntities() async throws -> [TodaySessionEntity] {
        let entity: TodaySessionEntity? = try await loadToday()
        if let entity { return [entity] }
        return []
    }

    /// Pulls the shared DatabaseWriter that the host app bootstrapped at
    /// launch (see `bootstrapApp()`). Avoiding `@Dependency` as a stored
    /// property because the property wrapper isn't `Sendable` and this
    /// type must be — `EntityQuery: Sendable`.
    private func currentDatabase() -> any DatabaseWriter {
        Dependency(key: \DependencyValues.defaultDatabase).wrappedValue
    }

    /// Pulls the planned session whose week contains today, then enriches
    /// it with the latest VDOT-derived pace range. Returns nil if the
    /// runner hasn't set up a race goal yet, or if today's day-of-week
    /// has no scheduled session.
    func loadToday() async throws -> TodaySessionEntity? {
        let database = currentDatabase()
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar weekday: Sun=1 … Sat=7. Schema uses Mon=1 … Sun=7.
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1

        struct Snapshot {
            let session: PlannedSession
            let vdot: Double
        }

        let snapshot: Snapshot? = try await database.read { db in
            let weeks = try TrainingWeek.all.fetchAll(db)
            guard let week = TrainingWeek.current(in: weeks) else { return nil as Snapshot? }

            let session = try PlannedSession
                .where { $0.weekId.eq(week.id) }
                .where { $0.dayOfWeek.eq(dayOfWeek) }
                .fetchOne(db)
            guard let session else { return nil as Snapshot? }

            let goal = try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
            let vdot = goal?.currentVDOT ?? 40
            return Snapshot(session: session, vdot: vdot)
        }

        guard let snapshot else { return nil }

        let range: PaceZones.PaceRange? = snapshot.session.targetPaceZone.map { zone in
            VDOTCalculator.paceRange(for: zone, vdot: snapshot.vdot)
        }

        return TodaySessionEntity(
            id: "today",
            sessionType: snapshot.session.sessionType,
            sessionTitle: snapshot.session.sessionType.displayName,
            targetDistanceKm: snapshot.session.targetDistanceKm,
            targetDurationMin: snapshot.session.targetDurationMin,
            paceZone: snapshot.session.targetPaceZone,
            paceLowerSecPerKm: range?.lower,
            paceUpperSecPerKm: range?.upper
        )
    }
}
