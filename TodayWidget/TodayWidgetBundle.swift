import Dependencies
import RunCraftModels
import SwiftUI
import WidgetKit

@main
struct TodayWidgetBundle: WidgetBundle {
    init() {
        prepareDependencies { try! $0.bootstrapDatabase() }
    }

    var body: some Widget {
        TodaySessionWidget()
    }
}
