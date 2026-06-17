import Foundation

/// WCSession application context key for the pending workout payload.
/// Written by `HKWatchTriggerClient` (iOS) just before triggering Watch launch;
/// read by `WatchAppDelegate.handle(_:HKWorkoutConfiguration)` (watchOS).
public let pendingWorkoutPayloadContextKey = "io.marstudio.RunCraft.pendingWorkout"

#if os(iOS)
import Dependencies
import HealthKit
import os
import WatchConnectivity

let hkWatchTriggerLogger = Logger(subsystem: "io.marstudio.RunCraft", category: "HKWatchTrigger")

/// TCA dependency that:
///  1. Pushes the `WatchWorkoutPayload` into the WCSession application context.
///  2. Calls `HKHealthStore.startWatchApp(toHandle:)` to auto-launch RunCraftWatch
///     and invoke `WKApplicationDelegate.handle(_:HKWorkoutConfiguration)` on it.
public struct HKWatchTriggerClient: Sendable {
    public var startWatchSession: @Sendable (WatchWorkoutPayload) async throws -> Void

    public init(startWatchSession: @escaping @Sendable (WatchWorkoutPayload) async throws -> Void) {
        self.startWatchSession = startWatchSession
    }
}

extension HKWatchTriggerClient: DependencyKey {
    public static var liveValue: HKWatchTriggerClient {
        HKWatchTriggerClient { payload in
            // 1. Push payload via WCSession application context so the Watch reads it
            //    in receivedApplicationContext (fast) or didReceiveApplicationContext (slow).
            _ = WCSessionActivator.shared
            let wc = WCSession.default
            hkWatchTriggerLogger.log(
                "WCSession state=\(wc.activationState.rawValue, privacy: .public) reachable=\(wc.isReachable, privacy: .public)"
            )
            if wc.activationState == .activated, wc.isPaired, wc.isWatchAppInstalled,
               let data = try? JSONEncoder().encode(payload) {
                var ctx = wc.applicationContext
                ctx[pendingWorkoutPayloadContextKey] = data
                do {
                    try wc.updateApplicationContext(ctx)
                    hkWatchTriggerLogger.log(
                        "updated WCSession context with payload (\(data.count, privacy: .public) bytes, name: \(payload.name, privacy: .public))"
                    )
                } catch {
                    hkWatchTriggerLogger.error(
                        "updateApplicationContext failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            } else {
                hkWatchTriggerLogger.warning(
                    "WCSession not ready — Watch will rely on previously cached context"
                )
            }

            // 2. Launch / wake Watch app via HealthKit.
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor

            let store = HKHealthStore()
            hkWatchTriggerLogger.log(
                "calling startWatchApp(toHandle:) activityType=\(config.activityType.rawValue, privacy: .public)"
            )
            do {
                try await store.startWatchApp(toHandle: config)
                hkWatchTriggerLogger.log("startWatchApp(toHandle:) succeeded")
            } catch {
                hkWatchTriggerLogger.error(
                    "startWatchApp(toHandle:) failed: \(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        }
    }

    public static var testValue: HKWatchTriggerClient {
        HKWatchTriggerClient { _ in }
    }

    public static var previewValue: HKWatchTriggerClient { testValue }
}

extension DependencyValues {
    public var hkWatchTriggerClient: HKWatchTriggerClient {
        get { self[HKWatchTriggerClient.self] }
        set { self[HKWatchTriggerClient.self] = newValue }
    }
}
#endif
