//
//  ActiveWorkoutView.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/16.
//

import RunCraftModels
import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @State private var showEndConfirmation = false

    // MARK: - Derived appearance

    private var stepColor: Color {
        switch manager.stepKind {
        case .warmup:   .orange
        case .work:     .green
        case .recovery: .cyan
        case .cooldown: .yellow
        case nil:       .blue
        }
    }

    private var hrZoneNumber: Int {
        let bpm = manager.heartRate
        guard bpm > 0 else { return 0 }
        if bpm < 120  { return 1 }
        if bpm < 140  { return 2 }
        if bpm < 160  { return 3 }
        if bpm < 175  { return 4 }
        return 5
    }

    private var hrZoneColor: Color {
        switch hrZoneNumber {
        case 1:  .gray
        case 2:  .green
        case 3:  .yellow
        case 4:  .orange
        case 5:  .red
        default: .secondary
        }
    }

    // MARK: - Body

    var body: some View {
        TabView {
            metricsPage
            controlsPage
        }
        .tabViewStyle(.page)
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) { manager.endWorkout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Metrics page

    private var metricsPage: some View {
        VStack(spacing: 5) {
            stepHeader
            progressRing
                .frame(maxHeight: .infinity)
            bottomStats
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var stepHeader: some View {
        HStack(spacing: 4) {
            if let kind = manager.stepKind {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(manager.stepName.isEmpty ? "Workout" : manager.stepName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if !manager.stepGoalText.isEmpty {
                Text(manager.stepGoalText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(stepColor)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 9)
            Circle()
                .trim(from: 0, to: manager.stepProgress)
                .stroke(stepColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.4), value: manager.stepProgress)
            VStack(spacing: 1) {
                Text(manager.paceText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(manager.paceUnitLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var bottomStats: some View {
        HStack(alignment: .top, spacing: 0) {
            // HR + zone indicator
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(hrZoneColor)
                        .monospacedDigit()
                    Text("bpm")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { zone in
                        Circle()
                            .fill(zone <= hrZoneNumber ? hrZoneColor : Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Distance
            VStack(alignment: .center, spacing: 1) {
                Text(manager.distanceText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("dist")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Elapsed time
            VStack(alignment: .trailing, spacing: 1) {
                Text(manager.elapsedTimeText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text("time")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Controls page

    private var controlsPage: some View {
        VStack(spacing: 12) {
            if case .paused = manager.phase {
                Button("Resume") { manager.resumeWorkout() }
                    .tint(.green)
            } else {
                Button("Pause") { manager.pauseWorkout() }
                    .tint(.yellow)
            }
            Button("End Workout") { showEndConfirmation = true }
                .tint(.red)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Work step") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.stepName = "Rep 2/5 · Run"
        m.stepGoalText = "1000 m"
        m.stepProgress = 0.68
        m.stepKind = .work
        m.heartRate = 162
        m.paceSecPerKm = 292
        m.totalMetres = 1680
        m.elapsedSeconds = 487
        return m
    }())
}

#Preview("Warmup") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.stepName = "Warm-up"
        m.stepGoalText = "5 min"
        m.stepProgress = 0.3
        m.stepKind = .warmup
        m.heartRate = 128
        m.paceSecPerKm = 360
        m.totalMetres = 420
        m.elapsedSeconds = 90
        return m
    }())
}

#Preview("Paused / Z5") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .paused
        m.stepName = "Rep 4/5 · Run"
        m.stepGoalText = "1000 m"
        m.stepProgress = 0.45
        m.stepKind = .work
        m.heartRate = 182
        m.paceSecPerKm = 275
        m.totalMetres = 3450
        m.elapsedSeconds = 1243
        return m
    }())
}
