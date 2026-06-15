import WidgetKit
import SwiftUI

struct TodaySessionWidget: Widget {
    let kind: String = "TodaySessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaySessionProvider()) { entry in
            TodaySessionWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Run")
        .description("See and start today's planned training session.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    TodaySessionWidget()
} timeline: {
    TodaySessionEntry.placeholder
}

#Preview(as: .systemMedium) {
    TodaySessionWidget()
} timeline: {
    TodaySessionEntry.placeholder
}
