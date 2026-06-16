//
//  WatchAppDelegate.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/16.
//

import AppleWatchSync
import Combine
import Foundation
import HealthKit
import RunCraftModels
import WatchConnectivity
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate, ObservableObject, @unchecked Sendable {

    let workoutManager = WorkoutSessionManager()
    @Published var schedule: WatchSchedulePayload?

    // MARK: - WKApplicationDelegate

    func applicationDidFinishLaunching() {
        // Activate WCSession early so receivedApplicationContext is available
        // when handle(_:HKWorkoutConfiguration) fires.
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        if let data = WCSession.default.receivedApplicationContext["schedule"] as? Data,
           let payload = try? JSONDecoder().decode(WatchSchedulePayload.self, from: data) {
            schedule = payload
        }
    }

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        // Read the workout blocks the iPhone queued via updateApplicationContext.
        let context = WCSession.isSupported() ? WCSession.default.receivedApplicationContext : [:]
        let blocks: [WorkoutBlock] = {
            guard let data = context["payload"] as? Data,
                  let payload = try? JSONDecoder().decode(WatchWorkoutPayload.self, from: data)
            else { return [] }
            return payload.blocks
        }()

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
                let session = try HKWorkoutSession(
                    healthStore: healthStore,
                    configuration: workoutConfiguration
                )
                try self.workoutManager.startWorkout(
                    session: session,
                    blocks: blocks,
                    healthStore: healthStore
                )
            } catch {
                self.workoutManager.phase = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["schedule"] as? Data,
              let payload = try? JSONDecoder().decode(WatchSchedulePayload.self, from: data)
        else { return }
        Task { @MainActor in
            self.schedule = payload
        }
    }
}
