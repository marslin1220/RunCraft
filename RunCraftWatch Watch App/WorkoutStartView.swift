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

                ForEach(Array(stepDescriptions.enumerated()), id: \.offset) { _, desc in
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

    // MARK: - Step descriptions

    private var stepDescriptions: [String] {
        payload.blocks.flatMap { block -> [String] in
            switch block {
            case .step(let s):
                return [stepLabel(s)]
            case .repeatGroup(let g):
                let header = "\(g.iterations)× repeat"
                let lines = g.steps.map { "  \(stepLabel($0))" }
                return [header] + lines
            }
        }
    }

    private func stepLabel(_ step: WorkoutStep) -> String {
        let kindName = step.kind.displayName
        switch step.goal {
        case .openEnded:
            return kindName
        case .distance(let m):
            let dist = m >= 1000
                ? String(format: "%.1f km", m / 1_000)
                : "\(Int(m)) m"
            return "\(kindName) · \(dist)"
        case .time(let s):
            let mins = s / 60
            let secs = s % 60
            let timeStr = secs == 0 ? "\(mins) min" : "\(mins):\(String(format: "%02d", secs))"
            return "\(kindName) · \(timeStr)"
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
                try manager.startWorkout(session: session, blocks: payload.blocks, healthStore: healthStore)
            } catch {
                isStarting = false
                manager.phase = .failed(error.localizedDescription)
            }
        }
    }
}
