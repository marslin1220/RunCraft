import AppFeature
import ComposableArchitecture
import RunCraftModels
import SwiftUI

@main
struct RunCraftApp: App {
    init() {
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
        }
    }
}
