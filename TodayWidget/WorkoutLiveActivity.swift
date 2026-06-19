import ActivityKit
import AppleWatchSync
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(context.state.heartRateText)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)
                                .monospacedDigit()
                            Text("bpm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if !context.state.hrZoneText.isEmpty {
                            Text(context.state.hrZoneText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(context.state.paceText)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(paceColor(context.state))
                            Text(context.state.paceUnitLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if context.state.avgPaceSecPerKm > 0 {
                            HStack(spacing: 2) {
                                Text(context.state.avgPaceText)
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                Text("avg")
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack {
                            Label(
                                context.state.stepName.isEmpty
                                    ? context.attributes.workoutName
                                    : context.state.stepName,
                                systemImage: context.state.isPaused ? "pause.circle.fill" : "figure.run"
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(context.state.isPaused ? .yellow : .green)
                            .lineLimit(1)
                            Spacer()
                            Text(context.state.elapsedTimeText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: context.state.stepProgress)
                            .tint(context.state.isPaused ? .yellow : .green)
                        if !context.state.stepGoalText.isEmpty {
                            HStack {
                                Text(context.state.distanceText)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Goal: \(context.state.stepGoalText)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    Text(context.state.heartRateText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                        .monospacedDigit()
                }
            } compactTrailing: {
                Text(context.state.paceText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(paceColor(context.state))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
            }
        }
    }

    private func paceColor(_ state: WorkoutActivityAttributes.ContentState) -> Color {
        switch state.paceDeviation {
        case .ahead:    .cyan
        case .behind:   .orange
        case .onTarget: .green
        case nil:       .primary
        }
    }
}

// MARK: - Lock Screen view

private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var stepColor: Color { context.state.isPaused ? .yellow : .green }

    private var paceColor: Color {
        switch context.state.paceDeviation {
        case .ahead:    .cyan
        case .behind:   .orange
        case .onTarget: .green
        case nil:       .primary
        }
    }

    private var hrZoneColor: Color {
        switch context.state.hrZone {
        case 1: .blue
        case 2: .green
        case 3: .yellow
        case 4: .orange
        case 5: .red
        default: .secondary
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            topRow
            progressSection
            metricsRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // Elapsed timer (hero) + step name
    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    context.state.stepName.isEmpty
                        ? context.attributes.workoutName
                        : context.state.stepName,
                    systemImage: context.state.isPaused ? "pause.circle.fill" : "figure.run"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(stepColor)
                .lineLimit(1)
            }
            Spacer()
            Text(context.state.elapsedTimeText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    // Progress bar + goal
    private var progressSection: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(stepColor)
                        .frame(width: geo.size.width * CGFloat(context.state.stepProgress))
                }
            }
            .frame(height: 4)
            if !context.state.stepGoalText.isEmpty {
                HStack {
                    Spacer()
                    Text("Goal: \(context.state.stepGoalText)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // Metrics: HR+zone | Pace | Distance
    private var metricsRow: some View {
        HStack(spacing: 0) {
            // HR + zone badge
            VStack(spacing: 2) {
                Text("HR")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(context.state.heartRateText)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                        .monospacedDigit()
                    Text("bpm")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                if !context.state.hrZoneText.isEmpty {
                    Text(context.state.hrZoneText)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(hrZoneColor, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 34)

            // Pace
            VStack(spacing: 2) {
                Text("Pace")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(context.state.paceText)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(paceColor)
                        .monospacedDigit()
                    Text(context.state.paceUnitLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                if context.state.avgPaceSecPerKm > 0 {
                    Text("\(context.state.avgPaceText) avg")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 34)

            // Distance
            VStack(spacing: 2) {
                Text("Dist")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(context.state.distanceText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview helpers

extension WorkoutActivityAttributes {
    static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(workoutName: "Interval Run")
    }
}

extension WorkoutActivityAttributes.ContentState {
    static var running: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            stepName: "Rep 2/5 · Run",
            stepGoalText: "1000 m",
            stepProgress: 0.68,
            heartRate: 162,
            avgHeartRate: 157,
            paceSecPerKm: 302,
            avgPaceSecPerKm: 310,
            targetPaceLo: 285,
            targetPaceHi: 315,
            totalMetres: 2680,
            elapsedSeconds: 1123,
            isPaused: false,
            isPerMile: false,
            hrZone: 4
        )
    }

    static var runningAhead: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            stepName: "Rep 4/5 · Run",
            stepGoalText: "1000 m",
            stepProgress: 0.35,
            heartRate: 175,
            avgHeartRate: 168,
            paceSecPerKm: 268,
            avgPaceSecPerKm: 278,
            targetPaceLo: 285,
            targetPaceHi: 315,
            totalMetres: 3900,
            elapsedSeconds: 1372,
            isPaused: false,
            isPerMile: false,
            hrZone: 5
        )
    }

    static var paused: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            stepName: "Rep 2/5 · Run",
            stepGoalText: "1000 m",
            stepProgress: 0.45,
            heartRate: 148,
            avgHeartRate: 155,
            paceSecPerKm: 0,
            avgPaceSecPerKm: 310,
            totalMetres: 2130,
            elapsedSeconds: 840,
            isPaused: true,
            isPerMile: false,
            hrZone: 3
        )
    }

    static var easyRun: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            stepName: "Easy Run",
            stepGoalText: "8 km",
            stepProgress: 0.52,
            heartRate: 138,
            avgHeartRate: 134,
            paceSecPerKm: 365,
            avgPaceSecPerKm: 372,
            totalMetres: 4160,
            elapsedSeconds: 1520,
            isPaused: false,
            isPerMile: false,
            hrZone: 2
        )
    }
}

#Preview("Lock screen — running (Zone 4, on target)", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.running
}

#Preview("Lock screen — ahead (Zone 5)", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.runningAhead
}

#Preview("Lock screen — paused", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.paused
}

#Preview("Lock screen — easy run (Zone 2, no target)", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.easyRun
}
