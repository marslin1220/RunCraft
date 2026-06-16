//
//  RunCraftWatchApp.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/15.
//

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

private struct RootView: View {
    @ObservedObject var appDelegate: WatchAppDelegate

    var body: some View {
        let manager = appDelegate.workoutManager
        switch manager.phase {
        case .running, .paused:
            ActiveWorkoutView(manager: manager)
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
            WatchHomeView(schedule: appDelegate.schedule, manager: manager)
        }
    }
}
