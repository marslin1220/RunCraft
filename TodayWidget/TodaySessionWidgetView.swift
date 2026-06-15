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
            SmallSessionView(session: entry.session)
        case .accessoryRectangular:
            RectangularSessionView(session: entry.session)
        case .accessoryCircular:
            CircularSessionView(session: entry.session)
        default:
            MediumSessionView(session: entry.session)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryRectangular, .accessoryCircular:
            Color.clear
        default:
            Color.brand.surface
        }
    }
}

// MARK: - Home Screen

private struct SmallSessionView: View {
    let session: TodaySessionEntity?

    var body: some View {
        Group {
            if let session, session.sessionType != .rest {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: session.sessionType.symbolName)
                        .font(.title2)
                        .foregroundStyle(Color.brand.accent)
                    Text(session.sessionTitle)
                        .font(.headline)
                        .foregroundStyle(Color.brand.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if let line = SessionDisplay.metricsLine(for: session) {
                        Text(line)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color.brand.textSecondary)
                    }
                }
            } else if let session {
                RestDayView(session: session)
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumSessionView: View {
    let session: TodaySessionEntity?

    var body: some View {
        Group {
            if let session, session.sessionType != .rest {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: session.sessionType.symbolName)
                                .font(.title3)
                                .foregroundStyle(Color.brand.accent)
                            Text(session.sessionTitle)
                                .font(.headline)
                                .foregroundStyle(Color.brand.textPrimary)
                        }
                        if let line = SessionDisplay.metricsLine(for: session) {
                            Text(line)
                                .font(.title3.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Color.brand.textPrimary)
                        }
                        if let line = SessionDisplay.paceLine(for: session) {
                            Text(line)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.brand.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(intent: StartTodaysSessionIntent()) {
                        Text("Send to Watch")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand.accent)
                }
            } else if let session {
                HStack {
                    RestDayView(session: session)
                    Spacer(minLength: 0)
                }
            } else {
                HStack {
                    EmptyStateView()
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

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

private struct RestDayView: View {
    let session: TodaySessionEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: session.sessionType.symbolName)
                    .foregroundStyle(Color.brand.accent)
                Text("Rest day")
                    .font(.headline)
                    .foregroundStyle(Color.brand.textPrimary)
            }
            Text("No run scheduled today")
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
    /// "8 km" / "45 min" — the headline metric for a session.
    static func metricsLine(for session: TodaySessionEntity) -> String? {
        if let km = session.targetDistanceKm {
            return PaceFormatting.distance(metres: km * 1_000, unit: .current)
        } else if let minutes = session.targetDurationMin {
            return "\(minutes) min"
        }
        return nil
    }

    /// "T · 5:30 – 6:00 /km" — pace zone letter plus its target range.
    static func paceLine(for session: TodaySessionEntity) -> String? {
        guard let zone = session.paceZone,
              let lower = session.paceLowerSecPerKm,
              let upper = session.paceUpperSecPerKm
        else { return nil }
        let range = PaceZones.PaceRange(lower: lower, upper: upper)
        return "\(zone.letter) · \(range.formatted(unit: .current))"
    }

    /// A bare number for the accessory-circular family, which has no room
    /// for a unit suffix.
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
