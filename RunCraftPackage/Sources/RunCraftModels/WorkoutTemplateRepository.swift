import Dependencies
import Foundation
import SQLiteData

/// Persistence seam for `WorkoutTemplate`.
///
/// All callers that previously reached for `@Dependency(\.defaultDatabase)`
/// to upsert, query or remove templates now go through this dependency.
/// Tests substitute `testValue` (no-op defaults) and override individual
/// closures to assert behaviour without spinning up SQLiteData.
public struct WorkoutTemplateRepository: Sendable {
    /// Insert or update — the repository decides which by looking up `id`.
    /// Returns the persisted id.
    public var save: @Sendable (WorkoutTemplate) async throws -> UUID
    /// Look up a template by id. Returns `nil` if absent.
    public var load: @Sendable (UUID) async throws -> WorkoutTemplate?
    /// All templates, newest-`updatedAt` first.
    public var all: @Sendable () async throws -> [WorkoutTemplate]
    /// Remove by id. Silently no-op if the row is absent.
    public var delete: @Sendable (UUID) async throws -> Void

    public init(
        save: @escaping @Sendable (WorkoutTemplate) async throws -> UUID,
        load: @escaping @Sendable (UUID) async throws -> WorkoutTemplate?,
        all:  @escaping @Sendable () async throws -> [WorkoutTemplate],
        delete: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.save = save
        self.load = load
        self.all = all
        self.delete = delete
    }
}

// MARK: - DependencyKey

extension WorkoutTemplateRepository: DependencyKey {
    public static var liveValue: Self {
        @Dependency(\.defaultDatabase) var database
        return Self(
            save: { template in
                try await database.write { db in
                    let existing = try WorkoutTemplate.find(template.id).fetchOne(db)
                    if existing != nil {
                        try WorkoutTemplate
                            .where { $0.id.eq(template.id) }
                            .update {
                                $0.name = template.name
                                $0.blocksData = template.blocksData
                                $0.updatedAt = template.updatedAt
                            }
                            .execute(db)
                    } else {
                        try WorkoutTemplate.insert { template }.execute(db)
                    }
                }
                return template.id
            },
            load: { id in
                try await database.read { db in
                    try WorkoutTemplate.find(id).fetchOne(db)
                }
            },
            all: {
                try await database.read { db in
                    try WorkoutTemplate.order { $0.updatedAt.desc() }.fetchAll(db)
                }
            },
            delete: { id in
                try await database.write { db in
                    try WorkoutTemplate
                        .where { $0.id.eq(id) }
                        .delete()
                        .execute(db)
                }
            }
        )
    }

    /// Sensible defaults so TestStore tests run without crashes. Tests that
    /// care about persistence behaviour override the specific closure they
    /// want to assert against.
    public static var testValue: Self {
        Self(
            save:   { $0.id },
            load:   { _ in nil },
            all:    { [] },
            delete: { _ in }
        )
    }

    public static var previewValue: Self { testValue }
}

extension DependencyValues {
    public var workoutTemplateRepository: WorkoutTemplateRepository {
        get { self[WorkoutTemplateRepository.self] }
        set { self[WorkoutTemplateRepository.self] = newValue }
    }
}
