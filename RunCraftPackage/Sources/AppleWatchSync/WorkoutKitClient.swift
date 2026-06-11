import Dependencies
import Foundation
import RunCraftModels
#if canImport(WorkoutKit)
import WorkoutKit
import HealthKit
#endif

/// TCA dependency wrapping WorkoutKit `WorkoutPlan` operations so the
/// reducer can request authorization and push workouts to Apple Watch
/// without importing WorkoutKit directly.
public struct WorkoutKitClient: Sendable {
    public var isAvailable: @Sendable () -> Bool
    public var requestAuthorization: @Sendable () async throws -> AuthState
    /// Build a custom workout from our template and open it in the
    /// paired Apple Watch's Workout app.
    public var openInWorkoutApp: @Sendable (WorkoutTemplate) async throws -> Void

    public init(
        isAvailable: @escaping @Sendable () -> Bool,
        requestAuthorization: @escaping @Sendable () async throws -> AuthState,
        openInWorkoutApp: @escaping @Sendable (WorkoutTemplate) async throws -> Void
    ) {
        self.isAvailable = isAvailable
        self.requestAuthorization = requestAuthorization
        self.openInWorkoutApp = openInWorkoutApp
    }
}

public enum AuthState: String, Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
}

public enum WorkoutKitError: LocalizedError {
    case unsupportedPlatform
    case watchNotPaired
    case notAuthorized
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return String(localized: "WorkoutKit requires iOS 17 or later.", bundle: .module)
        case .watchNotPaired:
            return String(localized: "No paired Apple Watch found. Pair a Watch in the Watch app.", bundle: .module)
        case .notAuthorized:
            return String(localized: "Apple Watch workout sync is not authorised. Tap to allow in Settings.", bundle: .module)
        case .conversionFailed(let r):
            return String(localized: "Could not convert workout: \(r)", bundle: .module)
        }
    }
}

// MARK: - Live

extension WorkoutKitClient: DependencyKey {
    public static var liveValue: WorkoutKitClient {
        #if canImport(WorkoutKit)
        WorkoutKitClient(
            isAvailable: { true },
            requestAuthorization: {
                let state = await WorkoutScheduler.shared.requestAuthorization()
                return Self.map(state)
            },
            openInWorkoutApp: { template in
                let plan = try WorkoutPlanBuilder.makePlan(from: template)
                let now = Date().addingTimeInterval(60)   // 1 min from now
                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: now
                )
                await WorkoutScheduler.shared.schedule(plan, at: comps)
            }
        )
        #else
        Self.unavailable
        #endif
    }

    public static var testValue: WorkoutKitClient {
        WorkoutKitClient(
            isAvailable: { true },
            requestAuthorization: { .authorized },
            openInWorkoutApp: { _ in }
        )
    }

    public static var previewValue: WorkoutKitClient { testValue }

    private static var unavailable: WorkoutKitClient {
        WorkoutKitClient(
            isAvailable: { false },
            requestAuthorization: { throw WorkoutKitError.unsupportedPlatform },
            openInWorkoutApp: { _ in throw WorkoutKitError.unsupportedPlatform }
        )
    }

    #if canImport(WorkoutKit)
    private static func map(_ state: WorkoutScheduler.AuthorizationState) -> AuthState {
        switch state {
        case .notDetermined: .notDetermined
        case .denied:        .denied
        case .restricted:    .restricted
        case .authorized:    .authorized
        @unknown default:    .notDetermined
        }
    }
    #endif
}

extension DependencyValues {
    public var workoutKitClient: WorkoutKitClient {
        get { self[WorkoutKitClient.self] }
        set { self[WorkoutKitClient.self] = newValue }
    }
}
