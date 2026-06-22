#if os(iOS)
import Dependencies
import Foundation
import HealthKit
import os

private let liveWorkoutLogger = Logger(subsystem: "io.marstudio.RunCraft", category: "LiveWorkout")

public enum LiveWorkoutEvent: Sendable {
    case sessionStarted
    case messageReceived(WorkoutMirrorMessage)
    case sessionPaused
    case sessionResumed
    case sessionEnded
}

/// TCA dependency that manages the iPhone side of a HealthKit Mirrored workout.
///
/// Set up by calling `events()` once at app launch via a long-lived `.run` effect.
/// The system calls `workoutSessionMirroringStartHandler` whenever the paired Watch
/// starts a mirrored `HKWorkoutSession`. All events (live metrics, state changes)
/// are delivered as an `AsyncStream<LiveWorkoutEvent>`.
public struct LiveWorkoutClient: Sendable {
    /// Subscribe to mirrored workout events. Call once from an `.onTask` effect.
    /// The stream never completes while the app is alive.
    public var events: @Sendable () -> AsyncStream<LiveWorkoutEvent>
    /// Send a control command to the Watch via the active mirrored session.
    public var sendCommand: @Sendable (WorkoutMirrorCommand) async -> Void

    public init(
        events: @escaping @Sendable () -> AsyncStream<LiveWorkoutEvent>,
        sendCommand: @escaping @Sendable (WorkoutMirrorCommand) async -> Void
    ) {
        self.events = events
        self.sendCommand = sendCommand
    }
}

extension LiveWorkoutClient: DependencyKey {
    public static var liveValue: LiveWorkoutClient {
        // Shared actor to hold the active mirrored session across closures.
        let coordinator = MirroringCoordinator()
        return LiveWorkoutClient(
            events: {
                AsyncStream { continuation in
                    coordinator.setContinuation(continuation)

                    let store = HKHealthStore()
                    coordinator.retainStore(store)
                    store.workoutSessionMirroringStartHandler = { mirroredSession in
                        liveWorkoutLogger.log("mirrored session started")
                        coordinator.attachSession(mirroredSession, continuation: continuation)
                        continuation.yield(.sessionStarted)
                    }
                    liveWorkoutLogger.log("workoutSessionMirroringStartHandler registered")

                    continuation.onTermination = { _ in
                        coordinator.detachSession()
                    }
                }
            },
            sendCommand: { command in
                await coordinator.send(command: command)
            }
        )
    }

    public static var testValue: LiveWorkoutClient {
        LiveWorkoutClient(
            events: { AsyncStream { _ in } },
            sendCommand: { _ in }
        )
    }

    public static var previewValue: LiveWorkoutClient { testValue }
}

extension DependencyValues {
    public var liveWorkoutClient: LiveWorkoutClient {
        get { self[LiveWorkoutClient.self] }
        set { self[LiveWorkoutClient.self] = newValue }
    }
}

// MARK: - Internal coordinator

private final class MirroringCoordinator: NSObject, HKWorkoutSessionDelegate, @unchecked Sendable {
    private var session: HKWorkoutSession?
    private var continuation: AsyncStream<LiveWorkoutEvent>.Continuation?
    // Retained here so workoutSessionMirroringStartHandler stays registered
    // for the lifetime of the stream. Without this, the local `store` in the
    // AsyncStream closure is released immediately after the closure returns,
    // silently removing the handler before any session arrives.
    private var healthStore: HKHealthStore?

    func setContinuation(_ continuation: AsyncStream<LiveWorkoutEvent>.Continuation) {
        self.continuation = continuation
    }

    func retainStore(_ store: HKHealthStore) {
        self.healthStore = store
    }

    func attachSession(
        _ mirroredSession: HKWorkoutSession,
        continuation: AsyncStream<LiveWorkoutEvent>.Continuation
    ) {
        self.session = mirroredSession
        self.continuation = continuation
        mirroredSession.delegate = self
    }

    func detachSession() {
        session = nil
        continuation = nil
        healthStore = nil
    }

    func send(command: WorkoutMirrorCommand) async {
        guard let session else {
            liveWorkoutLogger.error("sendCommand: no active mirrored session")
            return
        }
        guard let data = try? JSONEncoder().encode(command) else { return }
        do {
            try await session.sendToRemoteWorkoutSession(data: data)
            liveWorkoutLogger.log("sent command \(command.kind.rawValue, privacy: .public) to Watch")
        } catch {
            liveWorkoutLogger.error("sendCommand failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: HKWorkoutSessionDelegate

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        liveWorkoutLogger.log("mirrored session state → \(toState.rawValue, privacy: .public)")
        switch toState {
        case .running:  continuation?.yield(.sessionResumed)
        case .paused:   continuation?.yield(.sessionPaused)
        case .ended, .stopped: continuation?.yield(.sessionEnded)
        default: break
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        liveWorkoutLogger.error("mirrored session error: \(error.localizedDescription, privacy: .public)")
        continuation?.yield(.sessionEnded)
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        for item in data {
            if let message = try? JSONDecoder().decode(WorkoutMirrorMessage.self, from: item) {
                continuation?.yield(.messageReceived(message))
            }
        }
    }
}
#endif
