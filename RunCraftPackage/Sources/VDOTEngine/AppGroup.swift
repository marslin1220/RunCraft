import Foundation

/// Shared between the main app and any App Group member (the Today's-session
/// widget, future extensions) — both the SQLite container
/// (`RunCraftModels/Schema.swift`) and `UserDefaults` (the pace-unit
/// preference, see `PaceUnit.current`) need the same identifier so every
/// process sees the same data.
public let runCraftAppGroupIdentifier = "group.io.marstudio.RunCraft"

extension UserDefaults {
    /// The App Group's shared defaults. SwiftUI views read/write the
    /// pace-unit preference here via `@Shared(.appStorage(_:store:))` /
    /// `@AppStorage(_:store:)` so the Today's-session widget — which can't
    /// see `UserDefaults.standard` — observes the same value.
    /// `UserDefaults` is documented as thread-safe; Swift's strict
    /// concurrency checker doesn't know that, hence `nonisolated(unsafe)`.
    public nonisolated(unsafe) static let runCraftGroup = UserDefaults(suiteName: runCraftAppGroupIdentifier) ?? .standard
}
