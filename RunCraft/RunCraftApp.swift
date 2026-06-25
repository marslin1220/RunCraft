import AppFeature
import SwiftUI

@main
struct RunCraftApp: App {
    init() {
        bootstrapApp()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("--screenshots") {
                ScreenshotHost()
            } else {
                AppView(store: makeAppStore())
            }
            #else
            AppView(store: makeAppStore())
            #endif
        }
    }
}
