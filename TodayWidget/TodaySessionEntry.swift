import CoreLocation
import RunCraftIntents
import RunCraftModels
import VDOTEngine
import WeatherKit
import WidgetKit

// MARK: - Weather snapshot

/// Simplified weather group mapped from WeatherKit's `WeatherCondition`.
/// Each case maps to a localised rest-day tip and an SF Symbol.
enum WeatherConditionGroup: Equatable, Sendable {
    case sunny, partlyCloudy, cloudy, rainy, stormy, snow, windy, foggy

    var sfSymbol: String {
        switch self {
        case .sunny:        "sun.max.fill"
        case .partlyCloudy: "cloud.sun.fill"
        case .cloudy:       "cloud.fill"
        case .rainy:        "cloud.rain.fill"
        case .stormy:       "cloud.bolt.rain.fill"
        case .snow:         "snowflake"
        case .windy:        "wind"
        case .foggy:        "cloud.fog.fill"
        }
    }

    /// Xcstrings key for the rest-day tip message.
    var tipKey: String {
        switch self {
        case .sunny:        "weather.tip.sunny"
        case .partlyCloudy: "weather.tip.partlyCloudy"
        case .cloudy:       "weather.tip.cloudy"
        case .rainy:        "weather.tip.rainy"
        case .stormy:       "weather.tip.stormy"
        case .snow:         "weather.tip.snow"
        case .windy:        "weather.tip.windy"
        case .foggy:        "weather.tip.foggy"
        }
    }

    init(from condition: WeatherCondition) {
        switch condition {
        case .clear, .mostlyClear, .hot:
            self = .sunny
        case .partlyCloudy:
            self = .partlyCloudy
        case .mostlyCloudy, .cloudy:
            self = .cloudy
        case .drizzle, .rain, .heavyRain, .isolatedThunderstorms,
             .scatteredThunderstorms, .sunShowers:
            self = .rainy
        case .thunderstorms, .tropicalStorm, .hurricane, .hail, .strongStorms:
            self = .stormy
        case .snow, .heavySnow, .sleet, .freezingRain, .blizzard, .blowingSnow,
             .freezingDrizzle, .wintryMix, .frigid, .sunFlurries, .flurries:
            self = .snow
        case .windy, .breezy:
            self = .windy
        case .foggy, .haze, .smoky, .blowingDust:
            self = .foggy
        @unknown default:
            self = .cloudy
        }
    }
}

struct WeatherSnapshot: Equatable, Sendable {
    let condition: WeatherConditionGroup
}

// MARK: - Timeline entry

/// Timeline entry wrapping today's planned session, weekly progress, and
/// (optionally) a weather snapshot for the rest-day recovery tip.
struct TodaySessionEntry: TimelineEntry {
    let date: Date
    let session: TodaySessionEntity?
    let weekProgress: WeekProgressData
    let weather: WeatherSnapshot?

    static func current() async -> TodaySessionEntry {
        async let sessionTask = (try? await TodaySessionQuery().loadToday()) ?? nil
        async let progressTask = loadWeekProgress()
        async let weatherTask = Self.fetchWeather()
        return TodaySessionEntry(
            date: Date(),
            session: await sessionTask,
            weekProgress: await progressTask,
            weather: await weatherTask
        )
    }

    private static func fetchWeather() async -> WeatherSnapshot? {
        guard let location = CLLocationManager().location else { return nil }
        guard let weather = try? await WeatherService.shared.weather(for: location) else { return nil }
        return WeatherSnapshot(condition: WeatherConditionGroup(from: weather.currentWeather.condition))
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
        ),
        weekProgress: .placeholder,
        weather: nil
    )
}
