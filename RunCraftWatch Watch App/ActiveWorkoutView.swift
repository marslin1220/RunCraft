//
//  ActiveWorkoutView.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/16.
//

import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @State private var showEndConfirmation = false

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
        VStack(alignment: .leading, spacing: 6) {
            Text(manager.stepName.isEmpty ? "Workout" : manager.stepName)
                .font(.headline)
                .foregroundStyle(.tint)
                .lineLimit(1)

            ProgressView(value: manager.stepProgress)

            Text(manager.stepGoalText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                MetricCell(label: "HR", value: manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--", unit: "bpm")
                MetricCell(label: "Pace", value: manager.paceText, unit: manager.paceUnitLabel)
                MetricCell(label: "Dist", value: manager.distanceText, unit: "")
                MetricCell(label: "Time", value: manager.elapsedTimeText, unit: "")
            }
        }
        .padding()
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

// MARK: - MetricCell

private struct MetricCell: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Active") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.stepName = "Rep 2/5 · Run"
        m.stepGoalText = "1000 m"
        m.stepProgress = 0.68
        m.heartRate = 162
        m.paceSecPerKm = 292
        m.totalMetres = 1680
        m.elapsedSeconds = 487
        return m
    }())
}
