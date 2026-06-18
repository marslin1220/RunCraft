//
//  WorkoutStartView.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/16.
//

import AppleWatchSync
import HealthKit
import RunCraftModels
import SwiftUI

struct WorkoutStartView: View {
    let name: String
    let payload: WatchWorkoutPayload
    @ObservedObject var manager: WorkoutSessionManager
    @State private var isStarting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.tint)

                Divider()

                ForEach(Array(stepRows.enumerated()), id: \.offset) { _, row in
                    StepRowView(row: row)
                }

                Button {
                    guard !isStarting else { return }
                    isStarting = true
                    startWorkout()
                } label: {
                    if isStarting {
                        ProgressView()
                    } else {
                        Text("Start")
                    }
                }
                .disabled(isStarting)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step rows

    enum StepRow {
        case repeatHeader(String)
        case step(kind: StepKind, label: String, indented: Bool)
    }

    private var stepRows: [StepRow] {
        payload.blocks.flatMap { block -> [StepRow] in
            switch block {
            case .step(let s):
                return [.step(kind: s.kind, label: stepGoalText(s), indented: false)]
            case .repeatGroup(let g):
                let header = StepRow.repeatHeader("\(g.iterations)× repeat")
                let steps = g.steps.map { StepRow.step(kind: $0.kind, label: stepGoalText($0), indented: true) }
                return [header] + steps
            }
        }
    }

    private func stepGoalText(_ step: WorkoutStep) -> String {
        switch step.goal {
        case .openEnded:
            return step.kind.displayName
        case .distance(let m):
            let dist = m >= 1000
                ? String(format: "%.1f km", m / 1_000)
                : "\(Int(m)) m"
            return "\(step.kind.displayName) · \(dist)"
        case .time(let s):
            let mins = s / 60
            let secs = s % 60
            let timeStr = secs == 0 ? "\(mins) min" : "\(mins):\(String(format: "%02d", secs))"
            return "\(step.kind.displayName) · \(timeStr)"
        }
    }

    // MARK: - Start

    private func startWorkout() {
        Task { @MainActor in
            let healthStore = HKHealthStore()
            do {
                try await healthStore.requestAuthorization(
                    toShare: [
                        HKObjectType.workoutType(),
                        HKQuantityType(.activeEnergyBurned),
                        HKQuantityType(.distanceWalkingRunning),
                    ],
                    read: [
                        HKQuantityType(.heartRate),
                        HKQuantityType(.distanceWalkingRunning),
                        HKQuantityType(.runningSpeed),
                        HKQuantityType(.activeEnergyBurned),
                    ]
                )
                let config = HKWorkoutConfiguration()
                config.activityType = .running
                config.locationType = .outdoor
                let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                try await manager.startWorkout(session: session, blocks: payload.blocks, healthStore: healthStore)
            } catch {
                isStarting = false
                manager.phase = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - StepRowView

private struct StepRowView: View {
    let row: WorkoutStartView.StepRow

    var body: some View {
        switch row {
        case .repeatHeader(let text):
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        case .step(let kind, let label, let indented):
            HStack(spacing: 5) {
                if indented {
                    Spacer().frame(width: 8)
                }
                Image(systemName: kind.symbolName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(kind.stepColor)
                    .frame(width: 14)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
    }
}

private extension StepKind {
    var stepColor: Color {
        switch self {
        case .warmup:   .orange
        case .work:     .green
        case .recovery: .cyan
        case .cooldown: .yellow
        }
    }
}
