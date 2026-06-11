import Dependencies
import Foundation

public struct HealthKitClient: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Void
    /// Returns the best finishing time (seconds) for a given race distance, looking back 180 days.
    public var bestRaceTime: @Sendable (RaceDistanceQuery) async throws -> TimeInterval?
    /// Returns the average HRV (SDNN, ms) over the past 7 days.
    public var latestHRV: @Sendable () async throws -> Double?
    /// Returns the average nightly sleep hours over the past `nights` nights.
    public var recentSleepHours: @Sendable (_ nights: Int) async throws -> Double
    /// Returns all running HKWorkouts since `date`, projected into a lean
    /// summary the rest of the app can reason about without importing HealthKit.
    public var recentWorkouts: @Sendable (_ since: Date) async throws -> [HKWorkoutSummary]
    /// VO2max samples Apple Watch has captured in the last `daysBack` days,
    /// oldest first. Each sample carries the date the Watch decided it had
    /// enough signal — these are sporadic, not daily.
    public var recentVO2MaxSamples: @Sendable (_ daysBack: Int) async throws -> [VO2MaxSample]

    public init(
        requestAuthorization: @Sendable @escaping () async throws -> Void,
        bestRaceTime: @Sendable @escaping (RaceDistanceQuery) async throws -> TimeInterval?,
        latestHRV: @Sendable @escaping () async throws -> Double?,
        recentSleepHours: @Sendable @escaping (_ nights: Int) async throws -> Double,
        recentWorkouts: @Sendable @escaping (_ since: Date) async throws -> [HKWorkoutSummary],
        recentVO2MaxSamples: @Sendable @escaping (_ daysBack: Int) async throws -> [VO2MaxSample]
    ) {
        self.requestAuthorization = requestAuthorization
        self.bestRaceTime = bestRaceTime
        self.latestHRV = latestHRV
        self.recentSleepHours = recentSleepHours
        self.recentWorkouts = recentWorkouts
        self.recentVO2MaxSamples = recentVO2MaxSamples
    }
}

/// Apple-Watch-derived VO2max reading. Same unit (mL/(kg·min)) as Daniels'
/// VDOT, so the two are directly comparable for the Insights "delta" view.
/// The Watch produces these sporadically — typically after a run, but only
/// when GPS + heart-rate signal is strong enough for the estimator.
public struct VO2MaxSample: Sendable, Equatable, Identifiable {
    public let id: String
    public let recordedAt: Date
    public let vo2Max: Double

    public init(id: String, recordedAt: Date, vo2Max: Double) {
        self.id = id
        self.recordedAt = recordedAt
        self.vo2Max = vo2Max
    }
}

/// Lean projection of a HealthKit running workout — the bits we need to
/// match against PlannedSessions without leaking the HealthKit types.
public struct HKWorkoutSummary: Sendable, Equatable, Identifiable {
    public let id: String                 // HKWorkout.uuid.uuidString
    public let startDate: Date
    public let duration: TimeInterval     // seconds
    public let distanceMeters: Double

    public init(id: String, startDate: Date, duration: TimeInterval, distanceMeters: Double) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.distanceMeters = distanceMeters
    }
}

public enum RaceDistanceQuery: String, Sendable, CaseIterable, Equatable, Hashable {
    case fiveK
    case tenK
    case halfMarathon

    public var metres: Double {
        switch self {
        case .fiveK:        5_000
        case .tenK:         10_000
        case .halfMarathon: 21_097
        }
    }

    public var displayName: String {
        switch self {
        case .fiveK:        "5K"  // universal — never localized
        case .tenK:         "10K"
        case .halfMarathon: String(localized: "Half Marathon", bundle: .module)
        }
    }

    /// Typical finish time range hint shown in UI.
    public var typicalRange: String {
        switch self {
        case .fiveK:        String(localized: "15–60 min",   bundle: .module)
        case .tenK:         String(localized: "30–90 min",   bundle: .module)
        case .halfMarathon: String(localized: "1h 10m–3h",   bundle: .module)
        }
    }
}

// MARK: - DependencyKey

extension HealthKitClient: DependencyKey {
    public static var liveValue: HealthKitClient {
        LiveHealthKitClient.make()
    }

    public static var testValue: HealthKitClient {
        HealthKitClient(
            requestAuthorization: {},
            bestRaceTime: { _ in 25 * 60 },   // 25-min 5K → VDOT ≈ 40
            latestHRV: { 42.0 },
            recentSleepHours: { _ in 7.5 },
            recentWorkouts: { _ in [] },
            recentVO2MaxSamples: { _ in [] }
        )
    }

    public static var previewValue: HealthKitClient {
        testValue
    }
}

extension DependencyValues {
    public var healthKitClient: HealthKitClient {
        get { self[HealthKitClient.self] }
        set { self[HealthKitClient.self] = newValue }
    }
}
