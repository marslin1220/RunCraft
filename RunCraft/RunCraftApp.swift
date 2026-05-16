import AppFeature
import SwiftUI

@main
struct RunCraftApp: App {
    init() {
        bootstrapApp()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: makeAppStore())
        }
    }
}
