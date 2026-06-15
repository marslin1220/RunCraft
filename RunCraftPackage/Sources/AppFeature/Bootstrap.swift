import ComposableArchitecture
import Foundation
import RunCraftModels
import VDOTEngine
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
    migratePaceUnitToAppGroup()
    prepareDependencies {
        try! $0.bootstrapDatabase()
    }
}

/// `paceUnit` used to live in `UserDefaults.standard`, which the Today's-session
/// widget can't read. Copies any value the runner already set into the App
/// Group's shared defaults so existing installs don't lose their preference.
private func migratePaceUnitToAppGroup() {
    let group = UserDefaults.runCraftGroup
    guard group.string(forKey: "paceUnit") == nil,
          let existing = UserDefaults.standard.string(forKey: "paceUnit")
    else { return }
    group.set(existing, forKey: "paceUnit")
}
