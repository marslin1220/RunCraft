import RunCraftIntents
import RunCraftModels
import VDOTEngine
import WidgetKit

/// Timeline entry wrapping today's planned session, or `nil` if there's no
/// race goal yet / today's day-of-week has no scheduled session.
struct TodaySessionEntry: TimelineEntry {
    let date: Date
    let session: TodaySessionEntity?

    static func current() async -> TodaySessionEntry {
        let session = try? await TodaySessionQuery().loadToday()
        return TodaySessionEntry(date: Date(), session: session ?? nil)
    }

    /// Sample data for the widget gallery and the redacted placeholder.
    static let placeholder = TodaySessionEntry(
        date: Date(),
        session: TodaySessionEntity(
            id: "today",
            sessionType: .easy,
            sessionTitle: "Easy Run",
            targetDistanceKm: 8,
            targetDurationMin: nil,
            paceZone: .easy,
            paceLowerSecPerKm: 330,
            paceUpperSecPerKm: 360
        )
    )
}
