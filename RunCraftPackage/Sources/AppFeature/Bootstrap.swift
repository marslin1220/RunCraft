import ComposableArchitecture
import RunCraftModels
@_exported import RunCraftIntents

/// Creates the root store for the iOS app.
@MainActor
public func makeAppStore() -> StoreOf<AppFeature> {
    Store(initialState: AppFeature.State()) {
        AppFeature()
    }
}

/// Bootstraps the database dependency before the app scene is constructed.
public func bootstrapApp() {
    prepareDependencies {
        try! $0.bootstrapDatabase()
    }
}
