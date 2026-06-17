import Dependencies
import Foundation
import os
#if os(iOS) && canImport(WatchConnectivity)
import WatchConnectivity
#endif

let watchConnectivityLogger = Logger(subsystem: "io.marstudio.RunCraft", category: "WatchConnectivity")

/// TCA dependency wrapping `WCSession` for schedule sync from iPhone to Watch.
/// Workout payload delivery now goes through the App Group shared UserDefaults
/// (written by `HKWatchTriggerClient`) instead of WCSession.
public struct WatchConnectivityClient: Sendable {
    /// `true` when a Watch is paired and RunCraftWatch is installed —
    /// regardless of current reachability. Used to show/hide Watch-specific UI.
    public var isWatchPaired: @Sendable () -> Bool
    /// Pushes the current week's schedule + pace templates to the Watch via
    /// `updateApplicationContext["schedule"]`. Fire-and-forget; queued for
    /// delivery the next time the Watch app opens.
    public var sendSchedule: @Sendable (WatchSchedulePayload) async throws -> Void

    public init(
        isWatchPaired: @escaping @Sendable () -> Bool,
        sendSchedule: @escaping @Sendable (WatchSchedulePayload) async throws -> Void
    ) {
        self.isWatchPaired = isWatchPaired
        self.sendSchedule = sendSchedule
    }
}

public enum WatchConnectivityError: LocalizedError {
    case unsupportedPlatform
    /// Watch not paired or RunCraftWatch not installed.
    case watchNotAvailable

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return String(localized: "WatchConnectivity requires iOS.", bundle: .module)
        case .watchNotAvailable:
            return String(localized: "No paired Apple Watch with RunCraft installed was found.", bundle: .module)
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
        WatchConnectivityClient(isWatchPaired: { true }, sendSchedule: { _ in })
    }

    public static var previewValue: WatchConnectivityClient { testValue }

    private static var unavailable: WatchConnectivityClient {
        WatchConnectivityClient(
            isWatchPaired: { false },
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
