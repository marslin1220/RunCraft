#if os(iOS)
@preconcurrency import ActivityKit
import Dependencies
import Foundation
import os

private let liveActivityLogger = Logger(subsystem: "io.marstudio.RunCraft", category: "LiveActivity")

public struct LiveActivityClient: Sendable {
    /// Start a Live Activity for a new workout session.
    public var startSession: @Sendable (String, WorkoutMirrorMessage) async -> Void
    /// Update the Live Activity with the latest mirror message.
    public var updateSession: @Sendable (WorkoutMirrorMessage) async -> Void
    /// End the Live Activity immediately.
    public var endSession: @Sendable () async -> Void

    public init(
        startSession: @escaping @Sendable (String, WorkoutMirrorMessage) async -> Void,
        updateSession: @escaping @Sendable (WorkoutMirrorMessage) async -> Void,
        endSession: @escaping @Sendable () async -> Void
    ) {
        self.startSession = startSession
        self.updateSession = updateSession
        self.endSession = endSession
    }
}

extension LiveActivityClient: DependencyKey {
    public static var liveValue: LiveActivityClient {
        let manager = LiveActivityManager()
        return LiveActivityClient(
            startSession: { name, msg in await manager.start(workoutName: name, message: msg) },
            updateSession: { msg in await manager.update(message: msg) },
            endSession: { await manager.end() }
        )
    }

    public static var testValue: LiveActivityClient {
        LiveActivityClient(startSession: { _, _ in }, updateSession: { _ in }, endSession: {})
    }

    public static var previewValue: LiveActivityClient { testValue }
}

extension DependencyValues {
    public var liveActivityClient: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}

// MARK: - Manager

private actor LiveActivityManager {
    private var activity: Activity<WorkoutActivityAttributes>?

    func start(workoutName: String, message: WorkoutMirrorMessage) async {
        if let old = activity {
            await old.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
        let state = WorkoutActivityAttributes.ContentState.from(
            message: message,
            isPerMile: isPerMilePref()
        )
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            activity = try Activity.request(
                attributes: WorkoutActivityAttributes(workoutName: workoutName),
                content: content
            )
            liveActivityLogger.log("Live Activity started: \(workoutName, privacy: .public)")
        } catch {
            liveActivityLogger.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(message: WorkoutMirrorMessage) async {
        let state = WorkoutActivityAttributes.ContentState.from(
            message: message,
            isPerMile: isPerMilePref()
        )
        let content = ActivityContent(state: state, staleDate: nil)
        await activity?.update(content)
    }

    func end() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
        liveActivityLogger.log("Live Activity ended")
    }
}

private func isPerMilePref() -> Bool {
    UserDefaults(suiteName: "group.io.marstudio.RunCraft")?
        .string(forKey: "paceUnit") == "perMile"
}
#endif
