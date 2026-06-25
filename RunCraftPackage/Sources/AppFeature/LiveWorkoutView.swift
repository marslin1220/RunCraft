#if os(iOS)
import AppleWatchSync
import ComposableArchitecture
import DesignSystem
import SwiftUI
import VDOTEngine

public struct LiveWorkoutView: View {
    let store: StoreOf<AppFeature>
    let display: AppFeature.LiveWorkoutDisplay
    @AppStorage("paceUnit", store: .runCraftGroup) private var paceUnitRaw: String = PaceUnit.perKilometre.rawValue
    @State private var showEndConfirmation = false

    private var paceUnit: PaceUnit {
        PaceUnit(rawValue: paceUnitRaw) ?? .perKilometre
    }

    public var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                stepCard
                    .padding(.horizontal)

                metricsGrid
                    .padding(.horizontal)
                    .padding(.top, 16)

                Spacer()

                controlButtons
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled()
        .confirmationDialog(
            Text("End Workout?", bundle: .module),
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                store.send(.endWorkoutTapped)
            } label: {
                Text("End Workout", bundle: .module)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label { Text("On Apple Watch", bundle: .module) } icon: { Image(systemName: "applewatch") }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(verbatim: "LIVE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.green)
            }
        }
    }

    // MARK: - Step card

    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(display.message.stepName.isEmpty ? String(localized: "Workout", bundle: .module) : display.message.stepName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.brand.accent)
                .lineLimit(2)

            ProgressView(value: display.message.stepProgress)
                .tint(Color.brand.accent)

            if !display.message.stepGoalText.isEmpty {
                Text(display.message.stepGoalText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Metrics grid

    private var paceDeviationColor: Color? {
        let pace = display.message.paceSecPerKm
        guard pace > 0,
              let lo = display.message.targetPaceLo,
              let hi = display.message.targetPaceHi else { return nil }
        if pace < Double(lo) { return .cyan }    // ahead (faster than target window)
        if pace > Double(hi) { return .orange }  // behind (slower than target window)
        return .green                            // on target
    }

    private var hrZoneColor: Color {
        switch display.message.hrZone {
        case 1: .blue
        case 2: .green
        case 3: .yellow
        case 4: .orange
        case 5: .red
        default: .secondary
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            MetricTile(
                label: "HR",
                value: display.message.heartRate > 0 ? "\(Int(display.message.heartRate))" : "--",
                unit: "bpm",
                valueColor: display.message.hrZone > 0 ? hrZoneColor : nil,
                subValue: display.message.avgHeartRate > 0
                    ? "avg \(Int(display.message.avgHeartRate))" : nil
            )
            MetricTile(
                label: "Pace",
                value: display.message.paceSecPerKm > 0
                    ? PaceFormatting.paceMinutesSeconds(secondsPerKm: display.message.paceSecPerKm, unit: paceUnit)
                    : "--:--",
                unit: paceUnit.displayName,
                valueColor: paceDeviationColor,
                subValue: display.message.avgPaceSecPerKm > 0
                    ? "avg \(PaceFormatting.paceMinutesSeconds(secondsPerKm: display.message.avgPaceSecPerKm, unit: paceUnit))" : nil
            )
            MetricTile(
                label: "Dist",
                value: PaceFormatting.distance(metres: display.message.totalMetres, unit: paceUnit),
                unit: ""
            )
            MetricTile(
                label: "Time",
                value: elapsedTimeText,
                unit: ""
            )
        }
    }

    private var elapsedTimeText: String {
        let s = display.message.elapsedSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 16) {
            if display.message.isPaused {
                Button {
                    store.send(.resumeWorkoutTapped)
                } label: {
                    Text("Resume", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button {
                    store.send(.pauseWorkoutTapped)
                } label: {
                    Text("Pause", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                showEndConfirmation = true
            } label: {
                Text("End Workout", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .controlSize(.large)
    }
}

// MARK: - MetricTile

private struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    var valueColor: Color? = nil
    var subValue: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(valueColor ?? .primary)
            if !unit.isEmpty {
                Text(verbatim: unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let subValue {
                Text(verbatim: subValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - Preview

#Preview("Live Workout — on target (Zone 4)") {
    LiveWorkoutView(
        store: Store(initialState: AppFeature.State()) { AppFeature() },
        display: {
            var d = AppFeature.LiveWorkoutDisplay()
            d.message = WorkoutMirrorMessage(
                stepName: "Rep 2/5 · Run",
                stepGoalText: "1000 m",
                stepProgress: 0.68,
                heartRate: 162,
                avgHeartRate: 157,
                paceSecPerKm: 302,
                avgPaceSecPerKm: 310,
                targetPaceLo: 285,
                targetPaceHi: 315,
                totalMetres: 1680,
                elapsedSeconds: 487,
                isPaused: false,
                hrZone: 4
            )
            return d
        }()
    )
}

#Preview("Live Workout — ahead (Zone 5)") {
    LiveWorkoutView(
        store: Store(initialState: AppFeature.State()) { AppFeature() },
        display: {
            var d = AppFeature.LiveWorkoutDisplay()
            d.message = WorkoutMirrorMessage(
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
                hrZone: 5
            )
            return d
        }()
    )
}

#Preview("Live Workout — paused") {
    LiveWorkoutView(
        store: Store(initialState: AppFeature.State()) { AppFeature() },
        display: {
            var d = AppFeature.LiveWorkoutDisplay()
            d.message = WorkoutMirrorMessage(
                stepName: "Rep 2/5 · Run",
                stepGoalText: "1000 m",
                stepProgress: 0.45,
                heartRate: 148,
                avgHeartRate: 155,
                paceSecPerKm: 0,
                avgPaceSecPerKm: 310,
                targetPaceLo: 285,
                targetPaceHi: 315,
                totalMetres: 2130,
                elapsedSeconds: 840,
                isPaused: true,
                hrZone: 3
            )
            return d
        }()
    )
}
#endif
