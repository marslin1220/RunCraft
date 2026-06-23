import AppleWatchSync
import Combine
import CoreLocation
import Foundation
import HealthKit
import os
import RunCraftModels
import WatchConnectivity
import WatchKit

private nonisolated(unsafe) let watchLogger = Logger(subsystem: "io.marstudio.RunCraft.watchkitapp", category: "WatchAppDelegate")

final class WatchAppDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate, ObservableObject, @unchecked Sendable {

    let workoutManager = WorkoutSessionManager()
    @Published var schedule: WatchSchedulePayload? {
        didSet { persistSchedule() }
    }

    private static let kSchedule = "RunCraft.cachedSchedule"

    // Set by handle(_:) when the payload hasn't arrived yet.
    // Resolved by didReceiveApplicationContext or a 5-second timeout Task.
    private var pendingPayloadContinuation: CheckedContinuation<WatchWorkoutPayload?, Never>?
    private var gpsPrewarmManager: CLLocationManager?

    // MARK: - WKApplicationDelegate

    func applicationDidFinishLaunching() {
        watchLogger.log("applicationDidFinishLaunching")

        // Fast path: restore from local cache — available immediately without WCSession.
        loadCachedSchedule()

        requestHealthKitAuthorization()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()

        // Also merge whatever is already in the application context (may be newer than cache).
        let ctx = WCSession.default.receivedApplicationContext
        watchLogger.log("receivedApplicationContext keys: \(ctx.keys.sorted().joined(separator: ","), privacy: .public)")
        if let data = ctx["schedule"] as? Data,
           let payload = try? JSONDecoder().decode(WatchSchedulePayload.self, from: data) {
            schedule = payload  // didSet saves to cache
        }
    }

    private func loadCachedSchedule() {
        guard let data = UserDefaults.standard.data(forKey: Self.kSchedule),
              let payload = try? JSONDecoder().decode(WatchSchedulePayload.self, from: data)
        else { return }
        schedule = payload   // shows training list instantly on repeat launches
        watchLogger.log("schedule restored from local cache (\(data.count, privacy: .public) bytes)")
    }

    private func persistSchedule() {
        guard let payload = schedule,
              let data = try? JSONEncoder().encode(payload)
        else { return }
        UserDefaults.standard.set(data, forKey: Self.kSchedule)
        watchLogger.log("schedule persisted to local cache (\(data.count, privacy: .public) bytes)")
    }

    private func requestHealthKitAuthorization() {
        let healthStore = HKHealthStore()
        healthStore.requestAuthorization(
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
        ) { success, error in
            if let error {
                watchLogger.error("HealthKit auth error: \(error.localizedDescription, privacy: .public)")
            } else {
                watchLogger.log("HealthKit auth completed: success=\(success, privacy: .public)")
            }
        }
    }

    // nonisolated so the HealthKit daemon can call this from any thread.
    nonisolated func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        watchLogger.log("handle(_:HKWorkoutConfiguration) activityType=\(workoutConfiguration.activityType.rawValue, privacy: .public)")
        // Pre-warm GPS so the first location fix arrives before startActivity.
        // Stored as a property so it isn't deallocated before the request fires.
        let locationManager = CLLocationManager()
        gpsPrewarmManager = locationManager
        locationManager.requestLocation()
        Task { @MainActor in
            let payload = await waitForPayload()
            guard let payload else {
                watchLogger.error("no payload received within timeout — aborting")
                workoutManager.phase = .failed("Workout data not received from iPhone. Please try again.")
                return
            }
            watchLogger.log("got payload: \(payload.name, privacy: .public), \(payload.blocks.count, privacy: .public) blocks")
            await startWorkout(payload: payload, configuration: workoutConfiguration)
        }
    }

    // MARK: - Private

    private func waitForPayload() async -> WatchWorkoutPayload? {
        // Fast path: context was already delivered before handle(_:) ran.
        if let payload = payloadFromContext() {
            watchLogger.log("payload found immediately in receivedApplicationContext")
            return payload
        }

        // Slow path: wait for didReceiveApplicationContext, timeout after 5 s.
        watchLogger.log("payload not in context yet — awaiting didReceiveApplicationContext…")
        return await withCheckedContinuation { continuation in
            pendingPayloadContinuation = continuation
            Task {
                try? await Task.sleep(for: .seconds(5))
                if let c = pendingPayloadContinuation {
                    watchLogger.error("timed out waiting for workout payload")
                    pendingPayloadContinuation = nil
                    c.resume(returning: nil)
                }
            }
        }
    }

    private func payloadFromContext() -> WatchWorkoutPayload? {
        guard WCSession.isSupported(),
              let data = WCSession.default.receivedApplicationContext[pendingWorkoutPayloadContextKey] as? Data,
              let payload = try? JSONDecoder().decode(WatchWorkoutPayload.self, from: data)
        else { return nil }
        return payload
    }

    private func startWorkout(payload: WatchWorkoutPayload, configuration: HKWorkoutConfiguration) async {
        let healthStore = HKHealthStore()
        do {
            watchLogger.log("creating HKWorkoutSession")
            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            await workoutManager.runCountdown()
            try await workoutManager.startWorkout(
                session: session,
                blocks: payload.blocks,
                healthStore: healthStore
            )
            watchLogger.log("workoutManager.startWorkout succeeded")
        } catch {
            watchLogger.error("failed to start workout: \(error.localizedDescription, privacy: .public)")
            workoutManager.phase = .failed(error.localizedDescription)
        }
        gpsPrewarmManager = nil
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        watchLogger.log(
            "WCSession activated: state=\(activationState.rawValue, privacy: .public) error=\(error?.localizedDescription ?? "nil", privacy: .public)"
        )
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        watchLogger.log("didReceiveApplicationContext: keys=\(applicationContext.keys.sorted().joined(separator: ","), privacy: .public)")
        Task { @MainActor in
            // Resolve handle(_:) if it's waiting for the payload.
            if let data = applicationContext[pendingWorkoutPayloadContextKey] as? Data,
               let payload = try? JSONDecoder().decode(WatchWorkoutPayload.self, from: data) {
                if let continuation = pendingPayloadContinuation {
                    watchLogger.log("payload arrived — resolving handle(_:) continuation")
                    pendingPayloadContinuation = nil
                    continuation.resume(returning: payload)
                }
            }
            // Always apply schedule updates.
            if let data = applicationContext["schedule"] as? Data,
               let payload = try? JSONDecoder().decode(WatchSchedulePayload.self, from: data) {
                watchLogger.log("schedule updated (\(data.count, privacy: .public) bytes)")
                schedule = payload
            }
        }
    }
}
