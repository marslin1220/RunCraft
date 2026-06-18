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
                    VStack(alignment: .leading, spacing: 1) {
                        Label(context.state.heartRateText, systemImage: "heart.fill")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                            .monospacedDigit()
                        Text("bpm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(context.state.paceText)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(context.state.paceUnitLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
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
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Label(context.state.heartRateText, systemImage: "heart.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .monospacedDigit()
            } compactTrailing: {
                Text(context.state.paceText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Lock Screen / Notification Banner

private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var stepColor: Color { context.state.isPaused ? .yellow : .green }

    var body: some View {
        VStack(spacing: 8) {
            // Step name + elapsed time
            HStack {
                Label(
                    context.state.stepName.isEmpty
                        ? context.attributes.workoutName
                        : context.state.stepName,
                    systemImage: context.state.isPaused ? "pause.circle.fill" : "figure.run"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(stepColor)
                .lineLimit(1)
                Spacer()
                Text(context.state.elapsedTimeText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            // Step progress bar + goal
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.25))
                        Capsule()
                            .fill(stepColor)
                            .frame(width: geo.size.width * CGFloat(context.state.stepProgress))
                    }
                }
                .frame(height: 5)
                if !context.state.stepGoalText.isEmpty {
                    HStack {
                        Spacer()
                        Text("Goal: \(context.state.stepGoalText)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Metrics: HR | Pace | Distance
            HStack(spacing: 0) {
                LiveMetricView(
                    label: "HR",
                    value: context.state.heartRateText,
                    unit: "bpm",
                    color: .red
                )
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 28)
                LiveMetricView(
                    label: "Pace",
                    value: context.state.paceText,
                    unit: context.state.paceUnitLabel,
                    color: .primary
                )
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 28)
                LiveMetricView(
                    label: "Dist",
                    value: context.state.distanceText,
                    unit: "",
                    color: .primary
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct LiveMetricView: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

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
            paceSecPerKm: 292,
            totalMetres: 2680,
            elapsedSeconds: 1123,
            isPaused: false,
            isPerMile: false
        )
    }
    static var paused: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            stepName: "Rep 2/5 · Run",
            stepGoalText: "1000 m",
            stepProgress: 0.45,
            heartRate: 148,
            paceSecPerKm: 0,
            totalMetres: 2130,
            elapsedSeconds: 840,
            isPaused: true,
            isPerMile: false
        )
    }
}

#Preview("Lock screen – running", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.running
    WorkoutActivityAttributes.ContentState.paused
}
