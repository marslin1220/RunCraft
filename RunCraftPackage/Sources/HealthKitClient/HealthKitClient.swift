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
    /// Whether the app would need to (re-)request HealthKit read permission
    /// if it asked right now. `.needsRequest` after permission was already
    /// granted once means the runner revoked it via Settings.
    public var authorizationRequestStatus: @Sendable () async -> HealthAuthorizationRequestStatus
    /// Individual HRV (SDNN, ms) readings in the last `daysBack` days, oldest first.
    public var recentHRVSamples: @Sendable (_ daysBack: Int) async throws -> [HRVSample]
    /// Daily resting heart-rate readings in the last `daysBack` days, oldest first.
    public var recentRestingHRSamples: @Sendable (_ daysBack: Int) async throws -> [RestingHRSample]
    /// Daily-averaged running-form metrics (vertical oscillation, ground contact
    /// time, stride length) for the last `daysBack` days. Days with no run are
    /// omitted. All three series are fetched concurrently in the live value.
    public var recentRunningForm: @Sendable (_ daysBack: Int) async throws -> RunningFormTrend

    public init(
        requestAuthorization: @Sendable @escaping () async throws -> Void,
        bestRaceTime: @Sendable @escaping (RaceDistanceQuery) async throws -> TimeInterval?,
        latestHRV: @Sendable @escaping () async throws -> Double?,
        recentSleepHours: @Sendable @escaping (_ nights: Int) async throws -> Double,
        recentWorkouts: @Sendable @escaping (_ since: Date) async throws -> [HKWorkoutSummary],
        recentVO2MaxSamples: @Sendable @escaping (_ daysBack: Int) async throws -> [VO2MaxSample],
        authorizationRequestStatus: @Sendable @escaping () async -> HealthAuthorizationRequestStatus,
        recentHRVSamples: @Sendable @escaping (_ daysBack: Int) async throws -> [HRVSample],
        recentRestingHRSamples: @Sendable @escaping (_ daysBack: Int) async throws -> [RestingHRSample],
        recentRunningForm: @Sendable @escaping (_ daysBack: Int) async throws -> RunningFormTrend
    ) {
        self.requestAuthorization = requestAuthorization
        self.bestRaceTime = bestRaceTime
        self.latestHRV = latestHRV
        self.recentSleepHours = recentSleepHours
        self.recentWorkouts = recentWorkouts
        self.recentVO2MaxSamples = recentVO2MaxSamples
        self.authorizationRequestStatus = authorizationRequestStatus
        self.recentHRVSamples = recentHRVSamples
        self.recentRestingHRSamples = recentRestingHRSamples
        self.recentRunningForm = recentRunningForm
    }
}

/// Mirrors `HKAuthorizationRequestStatus` without leaking HealthKit types
/// into callers. `.needsRequest` covers both "never asked" and "revoked via
/// Settings" — callers distinguish the two using other evidence (e.g.
/// whether any HealthKit-derived data has been seen before).
public enum HealthAuthorizationRequestStatus: Sendable, Equatable {
    case authorized
    case needsRequest
    case unknown
}

/// A single dated value used for generic trends (RE metrics, etc.).
public struct DatedValue: Sendable, Equatable, Identifiable {
    public let id: String   // ISO8601 date string of the bucket start
    public let date: Date
    public let value: Double

    public init(id: String, date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

/// Running-form trend data for the last N days. Each array contains one
/// point per calendar day on which the Watch recorded samples. Days with
/// no run produce no entry (no zero-padding).
public struct RunningFormTrend: Sendable, Equatable {
    public let verticalOscillationCm: [DatedValue]
    public let groundContactTimeMs: [DatedValue]
    public let strideLengthM: [DatedValue]

    public init(
        verticalOscillationCm: [DatedValue],
        groundContactTimeMs: [DatedValue],
        strideLengthM: [DatedValue]
    ) {
        self.verticalOscillationCm = verticalOscillationCm
        self.groundContactTimeMs = groundContactTimeMs
        self.strideLengthM = strideLengthM
    }

    public static let empty = RunningFormTrend(
        verticalOscillationCm: [],
        groundContactTimeMs: [],
        strideLengthM: []
    )
}

/// Individual HRV reading (SDNN in milliseconds). Apple Watch records one
/// per significant daily activity; most runners get one per night.
public struct HRVSample: Sendable, Equatable, Identifiable {
    public let id: String
    public let recordedAt: Date
    public let sdnnMs: Double

    public init(id: String, recordedAt: Date, sdnnMs: Double) {
        self.id = id
        self.recordedAt = recordedAt
        self.sdnnMs = sdnnMs
    }
}

/// Daily resting heart rate (bpm) recorded by Apple Watch.
/// A declining trend over weeks indicates improving aerobic fitness.
public struct RestingHRSample: Sendable, Equatable, Identifiable {
    public let id: String
    public let recordedAt: Date
    public let bpm: Double

    public init(id: String, recordedAt: Date, bpm: Double) {
        self.id = id
        self.recordedAt = recordedAt
        self.bpm = bpm
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
            recentVO2MaxSamples: { _ in [] },
            authorizationRequestStatus: { .authorized },
            recentHRVSamples: { _ in [] },
            recentRestingHRSamples: { _ in [] },
            recentRunningForm: { _ in .empty }
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
