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
            Text("End Workout?"),
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                store.send(.endWorkoutTapped)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label("On Apple Watch", systemImage: "applewatch")
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
            Text(display.message.stepName.isEmpty ? "Workout" : display.message.stepName)
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
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Metrics grid

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            MetricTile(
                label: "HR",
                value: display.message.heartRate > 0 ? "\(Int(display.message.heartRate))" : "--",
                unit: "bpm"
            )
            MetricTile(
                label: "Pace",
                value: display.message.paceSecPerKm > 0
                    ? PaceFormatting.paceMinutesSeconds(secondsPerKm: display.message.paceSecPerKm, unit: paceUnit)
                    : "--:--",
                unit: paceUnit.displayName
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
                    Text("Resume")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button {
                    store.send(.pauseWorkoutTapped)
                } label: {
                    Text("Pause")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                showEndConfirmation = true
            } label: {
                Text("End Workout")
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
            if !unit.isEmpty {
                Text(verbatim: unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Preview

#Preview("Live Workout") {
    LiveWorkoutView(
        store: Store(initialState: AppFeature.State()) { AppFeature() },
        display: {
            var d = AppFeature.LiveWorkoutDisplay()
            d.message = WorkoutMirrorMessage(
                stepName: "Rep 2/5 · Run",
                stepGoalText: "1000 m",
                stepProgress: 0.68,
                heartRate: 162,
                paceSecPerKm: 292,
                totalMetres: 1680,
                elapsedSeconds: 487,
                isPaused: false
            )
            return d
        }()
    )
}
#endif
