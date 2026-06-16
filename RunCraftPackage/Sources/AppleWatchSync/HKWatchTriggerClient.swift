#if os(iOS)
import Dependencies
import Foundation
import HealthKit
import os

let hkWatchTriggerLogger = Logger(subsystem: "io.marstudio.RunCraft", category: "HKWatchTrigger")

/// TCA dependency that tells the paired Watch to auto-launch RunCraftWatch
/// and begin an HKWorkoutSession, using `HKHealthStore.startWatchApp(toHandle:)`.
///
/// Always paired with `WatchConnectivityClient.sendWorkout(_:)` — WCSession
/// delivers the block structure (the "what") while this client triggers the
/// Watch app launch and HealthKit session start (the "when").
public struct HKWatchTriggerClient: Sendable {
    public var startWatchSession: @Sendable () async throws -> Void

    public init(startWatchSession: @escaping @Sendable () async throws -> Void) {
        self.startWatchSession = startWatchSession
    }
}

extension HKWatchTriggerClient: DependencyKey {
    public static var liveValue: HKWatchTriggerClient {
        HKWatchTriggerClient {
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor

            let store = HKHealthStore()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.startWatchApp(with: config) { success, error in
                    if let error {
                        hkWatchTriggerLogger.error("startWatchApp failed: \(error.localizedDescription, privacy: .public)")
                        continuation.resume(throwing: error)
                    } else {
                        hkWatchTriggerLogger.log("startWatchApp succeeded")
                        continuation.resume()
                    }
                }
            }
        }
    }

    public static var testValue: HKWatchTriggerClient {
        HKWatchTriggerClient { }
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
