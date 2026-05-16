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

    public init(
        requestAuthorization: @Sendable @escaping () async throws -> Void,
        bestRaceTime: @Sendable @escaping (RaceDistanceQuery) async throws -> TimeInterval?,
        latestHRV: @Sendable @escaping () async throws -> Double?,
        recentSleepHours: @Sendable @escaping (_ nights: Int) async throws -> Double
    ) {
        self.requestAuthorization = requestAuthorization
        self.bestRaceTime = bestRaceTime
        self.latestHRV = latestHRV
        self.recentSleepHours = recentSleepHours
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
        case .fiveK:        "5K"
        case .tenK:         "10K"
        case .halfMarathon: "Half Marathon"
        }
    }

    /// Typical finish time range hint shown in UI.
    public var typicalRange: String {
        switch self {
        case .fiveK:        "15–60 min"
        case .tenK:         "30–90 min"
        case .halfMarathon: "1h 10m–3h"
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
            recentSleepHours: { _ in 7.5 }
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
