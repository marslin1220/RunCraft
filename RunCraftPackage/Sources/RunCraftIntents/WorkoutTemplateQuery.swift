import AppIntents
import Dependencies
import Foundation
import RunCraftModels
import SQLiteData
import WorkshopFeature

/// Resolves `WorkoutTemplateEntity` instances for App Intents parameter
/// pickers. Two sources unioned:
///
/// 1. Built-in presets (`WorkoutPresets.all`) — immutable, ship with the app.
/// 2. User-saved templates from SQLiteData.
///
/// Conforms to `EntityStringQuery` so Siri can match by name
/// (e.g. "Start Yasso 800") without an exact identifier.
public struct WorkoutTemplateQuery: EntityQuery, EntityStringQuery {

    public init() {}

    public func entities(for identifiers: [UUID]) async throws -> [WorkoutTemplateEntity] {
        let all = try await loadAll()
        let lookup = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return identifiers.compactMap { lookup[$0] }
    }

    public func entities(matching string: String) async throws -> [WorkoutTemplateEntity] {
        let needle = string.lowercased()
        let all = try await loadAll()
        return all.filter { $0.name.lowercased().contains(needle) }
    }

    public func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        try await loadAll()
    }

    // MARK: - Loading

    /// Returns presets first (stable order), then user templates ordered by
    /// most-recently-updated. Presets are tagged `isPreset = true` so the
    /// snippet view can distinguish them.
    func loadAll() async throws -> [WorkoutTemplateEntity] {
        let presets = WorkoutPresets.all.map {
            WorkoutTemplateEntity(template: $0, isPreset: true)
        }
        let userTemplates = try await loadUserTemplates().map {
            WorkoutTemplateEntity(template: $0, isPreset: false)
        }
        return presets + userTemplates
    }

    /// Same `@Dependency` macro workaround as `TodaySessionQuery` —
    /// inline access via `Dependency(key:)` to dodge the macro × Sendable
    /// compiler panic.
    private func loadUserTemplates() async throws -> [WorkoutTemplate] {
        let database: any DatabaseWriter = Dependency(key: \DependencyValues.defaultDatabase).wrappedValue
        return try await database.read { db in
            try WorkoutTemplate.order { $0.updatedAt.desc() }.fetchAll(db)
        }
    }
}
