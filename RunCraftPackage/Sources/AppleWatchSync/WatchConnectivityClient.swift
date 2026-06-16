import Dependencies
import Foundation
import os
#if os(iOS) && canImport(WatchConnectivity)
import WatchConnectivity
#endif

let watchConnectivityLogger = Logger(subsystem: "io.marstudio.RunCraft", category: "WatchConnectivity")

/// TCA dependency wrapping `WCSession` so a reducer can hand a workout to
/// the paired Apple Watch's RunCraftWatch app without importing
/// WatchConnectivity directly.
public struct WatchConnectivityClient: Sendable {
    /// `true` when a Watch is paired and RunCraftWatch is installed —
    /// regardless of current reachability. Used to show/hide Watch-specific UI.
    public var isWatchPaired: @Sendable () -> Bool
    public var sendWorkout: @Sendable (WatchWorkoutPayload) async throws -> Void
    /// Pushes the current week's schedule + pace templates to the Watch via
    /// `updateApplicationContext["schedule"]`. Fire-and-forget; queued for
    /// delivery the next time the Watch app opens.
    public var sendSchedule: @Sendable (WatchSchedulePayload) async throws -> Void

    public init(
        isWatchPaired: @escaping @Sendable () -> Bool,
        sendWorkout: @escaping @Sendable (WatchWorkoutPayload) async throws -> Void,
        sendSchedule: @escaping @Sendable (WatchSchedulePayload) async throws -> Void
    ) {
        self.isWatchPaired = isWatchPaired
        self.sendWorkout = sendWorkout
        self.sendSchedule = sendSchedule
    }
}

public enum WatchConnectivityError: LocalizedError {
    case unsupportedPlatform
    /// Watch not paired or RunCraftWatch not installed — can't deliver at all.
    case watchNotAvailable
    case sendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return String(localized: "WatchConnectivity requires iOS.", bundle: .module)
        case .watchNotAvailable:
            return String(localized: "No paired Apple Watch with RunCraft installed was found.", bundle: .module)
        case .sendFailed(let reason):
            return String(localized: "Could not send workout to Apple Watch: \(reason)", bundle: .module)
        }
    }
}

// MARK: - Live

extension WatchConnectivityClient: DependencyKey {
    public static var liveValue: WatchConnectivityClient {
        #if os(iOS) && canImport(WatchConnectivity)
        return WatchConnectivityClient(
            isWatchPaired: {
                _ = WCSessionActivator.shared
                let session = WCSession.default
                return session.activationState == .activated
                    && session.isPaired
                    && session.isWatchAppInstalled
            },
            sendWorkout: { payload in
                _ = WCSessionActivator.shared
                let session = WCSession.default
                guard session.activationState == .activated,
                      session.isPaired,
                      session.isWatchAppInstalled
                else {
                    throw WatchConnectivityError.watchNotAvailable
                }

                let data = try JSONEncoder().encode(payload)
                if session.isReachable {
                    // Fast path: Watch app is in foreground — deliver immediately.
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        session.sendMessage(
                            ["payload": data],
                            replyHandler: { _ in continuation.resume() },
                            errorHandler: { error in
                                continuation.resume(throwing: WatchConnectivityError.sendFailed(error.localizedDescription))
                            }
                        )
                    }
                } else {
                    // Slow path: merge into existing context so the "schedule"
                    // key isn't overwritten if it was pushed earlier.
                    do {
                        var ctx = session.applicationContext
                        ctx["payload"] = data
                        try session.updateApplicationContext(ctx)
                        watchConnectivityLogger.log("queued workout via application context")
                    } catch {
                        throw WatchConnectivityError.sendFailed(error.localizedDescription)
                    }
                }
            },
            sendSchedule: { schedulePayload in
                _ = WCSessionActivator.shared
                let session = WCSession.default
                guard session.activationState == .activated,
                      session.isPaired,
                      session.isWatchAppInstalled
                else { return }  // best-effort; Watch may not be paired yet

                let data = try JSONEncoder().encode(schedulePayload)
                var ctx = session.applicationContext
                ctx["schedule"] = data
                do {
                    try session.updateApplicationContext(ctx)
                    watchConnectivityLogger.log("queued schedule via application context")
                } catch {
                    watchConnectivityLogger.error("sendSchedule failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
        #else
        return Self.unavailable
        #endif
    }

    public static var testValue: WatchConnectivityClient {
        WatchConnectivityClient(isWatchPaired: { true }, sendWorkout: { _ in }, sendSchedule: { _ in })
    }

    public static var previewValue: WatchConnectivityClient { testValue }

    private static var unavailable: WatchConnectivityClient {
        WatchConnectivityClient(
            isWatchPaired: { false },
            sendWorkout: { _ in throw WatchConnectivityError.unsupportedPlatform },
            sendSchedule: { _ in }
        )
    }
}

extension DependencyValues {
    public var watchConnectivityClient: WatchConnectivityClient {
        get { self[WatchConnectivityClient.self] }
        set { self[WatchConnectivityClient.self] = newValue }
    }
}
