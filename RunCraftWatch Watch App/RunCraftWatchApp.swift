//
//  RunCraftWatchApp.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/15.
//

import AppleWatchSync
import SwiftUI

@main
struct RunCraftWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(appDelegate: appDelegate)
        }
    }
}

// Separate view so @ObservedObject on WorkoutSessionManager
// properly invalidates the body when phase changes.
private struct RootView: View {
    @ObservedObject var appDelegate: WatchAppDelegate

    var body: some View {
        WorkoutAwareView(
            schedule: appDelegate.schedule,
            manager: appDelegate.workoutManager
        )
    }
}

private struct WorkoutAwareView: View {
    let schedule: WatchSchedulePayload?
    @ObservedObject var manager: WorkoutSessionManager

    var body: some View {
        switch manager.phase {
        case .running, .openGoal, .paused:
            ActiveWorkoutView(manager: manager)
        case .countdown(let n):
            CountdownView(count: n)
        case .summary(let data):
            WorkoutSummaryView(data: data, manager: manager) {
                manager.dismissSummary()
            }
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)
                Text("Couldn't start workout")
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Dismiss") { manager.phase = .inactive }
                    .padding(.top, 4)
            }
            .padding()
            .multilineTextAlignment(.center)
        case .inactive:
            WatchHomeView(schedule: schedule, manager: manager)
        }
    }
}
