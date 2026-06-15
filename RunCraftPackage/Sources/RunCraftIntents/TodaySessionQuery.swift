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
    public func loadToday() async throws -> TodaySessionEntity? {
        let database = currentDatabase()

        let today = try await database.read { db in try TodaysSession.current(in: db) }
        guard let today else { return nil }

        let range: PaceZones.PaceRange? = today.session.targetPaceZone.map { zone in
            VDOTCalculator.paceRange(for: zone, vdot: today.vdot)
        }

        return TodaySessionEntity(
            id: "today",
            sessionType: today.session.sessionType,
            sessionTitle: today.session.sessionType.displayName,
            targetDistanceKm: today.session.targetDistanceKm,
            targetDurationMin: today.session.targetDurationMin,
            paceZone: today.session.targetPaceZone,
            paceLowerSecPerKm: range?.lower,
            paceUpperSecPerKm: range?.upper
        )
    }
}
