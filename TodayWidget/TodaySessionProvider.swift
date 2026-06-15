import WidgetKit

/// Today's session only changes once a day, so the timeline holds a single
/// entry and refreshes at the next local midnight.
struct TodaySessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySessionEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodaySessionEntry) -> Void) {
        Task { completion(await TodaySessionEntry.current()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySessionEntry>) -> Void) {
        Task {
            let entry = await TodaySessionEntry.current()
            let nextMidnight = Calendar.current.nextDate(
                after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
        }
    }
}
