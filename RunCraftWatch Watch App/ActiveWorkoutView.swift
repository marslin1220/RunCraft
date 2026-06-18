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
            intervalPage
            statsPage
            controlsPage
        }
        .tabViewStyle(.page)
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) { manager.endWorkout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Page 1: Interval (step header + 3 metrics + progress bar + next)

    private var intervalPage: some View {
        VStack(spacing: 0) {
            // Step name + position counter
            HStack(spacing: 4) {
                if let kind = manager.stepKind {
                    Image(systemName: kind.symbolName)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(manager.stepName.isEmpty ? "Workout" : manager.stepName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if manager.totalStepCount > 1 {
                    Text("\(manager.stepPosition)/\(manager.totalStepCount)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(stepColor)

            Spacer()

            // Three core metrics: Pace | HR | Remaining
            HStack(alignment: .top, spacing: 0) {
                // Pace (primary — largest)
                VStack(alignment: .leading, spacing: 1) {
                    Text(manager.paceText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(manager.paceUnitLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Heart rate + zone dots (centre)
                VStack(alignment: .center, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(hrZoneColor)
                            .monospacedDigit()
                        Text("bpm")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { z in
                            Circle()
                                .fill(z <= hrZoneNumber ? hrZoneColor : Color.secondary.opacity(0.2))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Remaining distance/time (right)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(manager.stepRemainingText.isEmpty ? "--" : manager.stepRemainingText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("left")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Spacer()

            // Step progress bar + goal label
            VStack(alignment: .leading, spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule()
                            .fill(stepColor)
                            .frame(width: geo.size.width * CGFloat(manager.stepProgress))
                            .animation(.linear(duration: 0.35), value: manager.stepProgress)
                    }
                }
                .frame(height: 6)
                if !manager.stepGoalText.isEmpty {
                    Text("Goal: \(manager.stepGoalText)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            // Next step hint
            if !manager.nextStepSummary.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                    Text(manager.nextStepSummary)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundStyle(.secondary.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Page 2: Stats (HR + distance + time)

    private var statsPage: some View {
        VStack(spacing: 10) {
            // Heart rate (large) + zone bar
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(hrZoneColor)
                        .monospacedDigit()
                    Text("bpm")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    ForEach(1...5, id: \.self) { zone in
                        Capsule()
                            .fill(zone <= hrZoneNumber ? hrZoneColor : Color.secondary.opacity(0.2))
                            .frame(height: 5)
                    }
                }
                .padding(.horizontal, 4)
            }

            Divider()

            // Distance + elapsed time side by side
            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text(manager.distanceText)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("dist")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 1) {
                    Text(manager.elapsedTimeText)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                    Text("time")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Page 3: Controls

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
        m.stepPosition = 4
        m.totalStepCount = 12
        m.nextStepSummary = "Rep 2/5 · Recovery · 90 sec"
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
        m.stepPosition = 1
        m.totalStepCount = 12
        m.nextStepSummary = "Rep 1/5 · Run · 1 km"
        return m
    }())
}

#Preview("Stats page") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.stepName = "Rep 4/5 · Run"
        m.stepGoalText = "1000 m"
        m.stepProgress = 0.45
        m.stepKind = .work
        m.heartRate = 172
        m.paceSecPerKm = 275
        m.totalMetres = 3450
        m.elapsedSeconds = 1243
        m.stepPosition = 9
        m.totalStepCount = 12
        m.nextStepSummary = "Rep 4/5 · Recovery · 90 sec"
        return m
    }())
}
