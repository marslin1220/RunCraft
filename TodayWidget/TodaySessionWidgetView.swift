import AppIntents
import DesignSystem
import RunCraftIntents
import RunCraftModels
import SwiftUI
import VDOTEngine
import WidgetKit

/// Family-adaptive root view for the Today's-session widget.
struct TodaySessionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TodaySessionEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            SmallSessionView(session: entry.session, weather: entry.weather)
        case .accessoryRectangular:
            RectangularSessionView(session: entry.session)
        case .accessoryCircular:
            CircularSessionView(session: entry.session)
        default:
            MediumSessionView(
                session: entry.session,
                weekProgress: entry.weekProgress,
                weather: entry.weather
            )
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryRectangular, .accessoryCircular:
            Color.clear
        default:
            LinearGradient(
                colors: [Color.brand.accent.opacity(0.10), Color.brand.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Home Screen / Small

private struct SmallSessionView: View {
    let session: TodaySessionEntity?
    let weather: WeatherSnapshot?

    var body: some View {
        Group {
            if let session, session.sessionType != .rest {
                Button(intent: StartTodaysSessionIntent()) {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: session.sessionType.symbolName)
                            .font(.title2)
                            .foregroundStyle(Color.brand.accent)
                        Spacer(minLength: 0)
                        Text(session.sessionTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.brand.textPrimary)
                            .lineLimit(2)
                            .padding(.top, 4)
                        if let line = SessionDisplay.metricsLine(for: session) {
                            Text(line)
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(Color.brand.textSecondary)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else if let session {
                SmallRestDayView(session: session, weather: weather)
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Home Screen / Medium

private struct MediumSessionView: View {
    let session: TodaySessionEntity?
    let weekProgress: WeekProgressData
    let weather: WeatherSnapshot?

    var body: some View {
        Group {
            if let session, session.sessionType != .rest {
                Button(intent: StartTodaysSessionIntent()) {
                    MediumWorkoutDayContent(session: session, weekProgress: weekProgress, weather: weather)
                }
                .buttonStyle(.plain)
            } else if let session {
                MediumRestDayView(session: session, weekProgress: weekProgress, weather: weather)
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumWorkoutDayContent: View {
    let session: TodaySessionEntity
    let weekProgress: WeekProgressData
    let weather: WeatherSnapshot?

    private var showWeatherAlert: Bool {
        guard let condition = weather?.condition else { return false }
        switch condition {
        case .rainy, .stormy, .snow: return true
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: session.sessionType.symbolName)
                    .font(.caption.weight(.semibold))
                Text(session.sessionType.displayName.uppercased())
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.brand.accent)

            Text(session.sessionTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.brand.textPrimary)
                .lineLimit(2)
                .padding(.top, 4)

            HStack(spacing: 6) {
                if let dist = SessionDisplay.metricsLine(for: session) {
                    Text(dist)
                }
                if let pace = SessionDisplay.paceLine(for: session) {
                    Text("·").opacity(0.4)
                    Text(pace)
                }
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color.brand.textSecondary)
            .padding(.top, 2)

            if showWeatherAlert, let weather {
                HStack(spacing: 4) {
                    Image(systemName: weather.condition.sfSymbol)
                    Text(LocalizedStringKey(weather.condition.trainingTipKey))
                }
                .font(.caption)
                .foregroundStyle(Color.brand.caution)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
            WeekProgressBar(progress: weekProgress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Rest day views

private struct SmallRestDayView: View {
    let session: TodaySessionEntity
    let weather: WeatherSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: session.sessionType.symbolName)
                    .foregroundStyle(Color.brand.accent)
                Text("Rest day")
                    .font(.headline)
                    .foregroundStyle(Color.brand.textPrimary)
            }
            if let weather {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: weather.condition.sfSymbol)
                        .font(.caption)
                        .foregroundStyle(Color.brand.accent)
                    Text(LocalizedStringKey(weather.condition.tipKey))
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                        .lineLimit(3)
                }
            } else {
                Text(LocalizedStringKey("rest.recovery.fallback"))
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                    .lineLimit(3)
            }
        }
    }
}

private struct MediumRestDayView: View {
    let session: TodaySessionEntity
    let weekProgress: WeekProgressData
    let weather: WeatherSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: session.sessionType.symbolName)
                    .font(.caption.weight(.semibold))
                Text("REST DAY")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.brand.accent)

            Group {
                if let weather {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: weather.condition.sfSymbol)
                            .font(.title3)
                            .foregroundStyle(Color.brand.accent)
                        Text(LocalizedStringKey(weather.condition.tipKey))
                            .lineLimit(3)
                    }
                } else {
                    Text(LocalizedStringKey("rest.recovery.fallback"))
                        .lineLimit(3)
                }
            }
            .font(.callout)
            .foregroundStyle(Color.brand.textPrimary)
            .padding(.top, 6)

            Spacer(minLength: 0)
            WeekProgressBar(progress: weekProgress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Week progress bar

private struct WeekProgressBar: View {
    let progress: WeekProgressData

    private var sessionText: String {
        String(
            format: String(localized: "week.progress.sessions"),
            progress.sessionsDone, progress.sessionsPlanned
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: progress.ratio)
                .tint(Color.brand.accent)
                .progressViewStyle(.linear)
            HStack {
                if progress.kmTarget > 0 {
                    Text(String(format: "%.1f / %.0f km", progress.kmDone, progress.kmTarget))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.brand.textSecondary)
                }
                Spacer()
                Text(sessionText)
                    .font(.caption2)
                    .foregroundStyle(Color.brand.textSecondary)
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No plan yet")
                .font(.headline)
                .foregroundStyle(Color.brand.textPrimary)
            Text("Open RunCraft to set up a plan")
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)
        }
    }
}

// MARK: - Lock Screen

private struct RectangularSessionView: View {
    let session: TodaySessionEntity?

    var body: some View {
        if let session, session.sessionType != .rest {
            Button(intent: StartTodaysSessionIntent()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.sessionTitle)
                        .font(.headline)
                        .lineLimit(1)
                    if let line = SessionDisplay.metricsLine(for: session) {
                        Text(line)
                            .font(.caption)
                    }
                }
            }
        } else if session != nil {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest day")
                    .font(.headline)
                Text("No run scheduled today")
                    .font(.caption)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("No plan yet")
                    .font(.headline)
                Text("Open RunCraft to set up a plan")
                    .font(.caption)
            }
        }
    }
}

private struct CircularSessionView: View {
    let session: TodaySessionEntity?

    var body: some View {
        if let session, session.sessionType != .rest {
            Button(intent: StartTodaysSessionIntent()) {
                circle(symbol: session.sessionType.symbolName, label: SessionDisplay.shortLabel(for: session))
            }
        } else {
            circle(symbol: session?.sessionType.symbolName ?? "calendar", label: nil)
        }
    }

    private func circle(symbol: String, label: String?) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.title3)
                if let label {
                    Text(label)
                        .font(.caption2)
                }
            }
        }
    }
}

// MARK: - Shared formatting

private enum SessionDisplay {
    static func metricsLine(for session: TodaySessionEntity) -> String? {
        if let km = session.targetDistanceKm {
            return PaceFormatting.distance(metres: km * 1_000, unit: .current)
        } else if let minutes = session.targetDurationMin {
            return "\(minutes) min"
        }
        return nil
    }

    static func paceLine(for session: TodaySessionEntity) -> String? {
        guard let zone = session.paceZone,
              let lower = session.paceLowerSecPerKm,
              let upper = session.paceUpperSecPerKm
        else { return nil }
        let range = PaceZones.PaceRange(lower: lower, upper: upper)
        return "\(zone.letter) · \(range.formatted(unit: .current))"
    }

    static func shortLabel(for session: TodaySessionEntity) -> String? {
        if let km = session.targetDistanceKm {
            let value = PaceFormatting.distanceValue(metres: km * 1_000, unit: .current)
            return value.formatted(.number.precision(.fractionLength(0...1)))
        } else if let minutes = session.targetDurationMin {
            return "\(minutes)'"
        }
        return nil
    }
}
