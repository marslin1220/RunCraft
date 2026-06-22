import Foundation
import HealthKit

enum LiveHealthKitClient {
    /// Read types requested by `requestAuthorization` — also the set checked
    /// by `getRequestStatusForAuthorization` to detect a revoked grant.
    private static let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .vo2Max)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .runningVerticalOscillation)!,
        HKObjectType.quantityType(forIdentifier: .runningGroundContactTime)!,
        HKObjectType.quantityType(forIdentifier: .runningStrideLength)!,
        HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)!,
    ]

    static func make() -> HealthKitClient {
        HealthKitClient(
            requestAuthorization: {
                guard HKHealthStore.isHealthDataAvailable() else { return }
                let store = HKHealthStore()
                try await store.requestAuthorization(toShare: [], read: readTypes)
            },
            bestRaceTime: { distance in
                try await bestRaceTime(for: distance)
            },
            latestHRV: {
                try await latestHRV()
            },
            recentSleepHours: { nights in
                try await recentSleepHours(nights: nights)
            },
            recentWorkouts: { since in
                try await recentWorkouts(since: since)
            },
            recentVO2MaxSamples: { daysBack in
                try await recentVO2MaxSamples(daysBack: daysBack)
            },
            authorizationRequestStatus: {
                await authorizationRequestStatus()
            },
            recentHRVSamples: { daysBack in
                try await recentHRVSamples(daysBack: daysBack)
            },
            recentRestingHRSamples: { daysBack in
                try await recentRestingHRSamples(daysBack: daysBack)
            },
            recentRunningForm: { daysBack in
                try await recentRunningForm(daysBack: daysBack)
            },
            recentHRRecoverySamples: { daysBack in
                try await recentHRRecoverySamples(daysBack: daysBack)
            }
        )
    }

    // MARK: - Authorization status

    private static func authorizationRequestStatus() async -> HealthAuthorizationRequestStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unknown }
        let store = HKHealthStore()

        return await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                switch status {
                case .unnecessary:    continuation.resume(returning: .authorized)
                case .shouldRequest:  continuation.resume(returning: .needsRequest)
                case .unknown:        continuation.resume(returning: .unknown)
                @unknown default:    continuation.resume(returning: .unknown)
                }
            }
        }
    }

    // MARK: - VO2max

    /// HealthKit unit is mL/(kg·min) — same as Daniels' VDOT — so values
    /// can be charted side-by-side without conversion.
    private static func recentVO2MaxSamples(daysBack: Int) async throws -> [VO2MaxSample] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let store = HKHealthStore()

        guard let vo2Type = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
            return []
        }
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        // Oldest first so the chart's x-axis lines up naturally.
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let unit = HKUnit(from: "mL/kg*min")

        return try await withCheckedThrowingContinuation { continuation in
            let hkQuery = HKSampleQuery(
                sampleType: vo2Type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let mapped = (samples as? [HKQuantitySample])?.map { sample in
                    VO2MaxSample(
                        id: sample.uuid.uuidString,
                        recordedAt: sample.startDate,
                        vo2Max: sample.quantity.doubleValue(for: unit)
                    )
                } ?? []
                continuation.resume(returning: mapped)
            }
            store.execute(hkQuery)
        }
    }

    // MARK: - Best race time

    private static func bestRaceTime(for query: RaceDistanceQuery) async throws -> TimeInterval? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let store = HKHealthStore()

        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForSamples(withStart: sixMonthsAgo, end: Date()),
        ])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let hkQuery = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }

                let targetMetres = query.metres
                let tolerance = targetMetres * 0.10

                let best = (samples as? [HKWorkout])?
                    .filter { workout in
                        guard let dist = workout.totalDistance?.doubleValue(for: .meter()) else { return false }
                        return abs(dist - targetMetres) <= tolerance
                    }
                    .map(\.duration)
                    .min()

                continuation.resume(returning: best)
            }
            store.execute(hkQuery)
        }
    }

    // MARK: - HRV samples (time-series)

    private static func recentHRVSamples(daysBack: Int) async throws -> [HRVSample] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let store = HKHealthStore()
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let mapped = (samples as? [HKQuantitySample])?.map { s in
                    HRVSample(id: s.uuid.uuidString, recordedAt: s.startDate,
                              sdnnMs: s.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                } ?? []
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    // MARK: - Resting HR

    private static func recentRestingHRSamples(daysBack: Int) async throws -> [RestingHRSample] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let store = HKHealthStore()
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return [] }
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let mapped = (samples as? [HKQuantitySample])?.map { s in
                    RestingHRSample(id: s.uuid.uuidString, recordedAt: s.startDate,
                                    bpm: s.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                } ?? []
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    // MARK: - Running form (RE proxies)

    private static func recentRunningForm(daysBack: Int) async throws -> RunningFormTrend {
        async let vo   = dailyAverages(for: .runningVerticalOscillation, unit: .meterUnit(with: .centi), daysBack: daysBack)
        async let gct  = dailyAverages(for: .runningGroundContactTime,   unit: .secondUnit(with: .milli), daysBack: daysBack)
        async let stride = dailyAverages(for: .runningStrideLength,       unit: .meter(), daysBack: daysBack)
        return try await RunningFormTrend(
            verticalOscillationCm: vo,
            groundContactTimeMs: gct,
            strideLengthM: stride
        )
    }

    /// Queries a quantity type using `HKStatisticsCollectionQuery` with a
    /// 1-day interval. Returns one `DatedValue` per day that has data.
    private static func dailyAverages(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        daysBack: Int
    ) async throws -> [DatedValue] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let store = HKHealthStore()
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: now)!
        // Anchor on midnight so buckets align to calendar days.
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                let points = results?.statistics().compactMap { stats -> DatedValue? in
                    guard let avg = stats.averageQuantity() else { return nil }
                    return DatedValue(
                        id: stats.startDate.ISO8601Format(),
                        date: stats.startDate,
                        value: avg.doubleValue(for: unit)
                    )
                } ?? []
                continuation.resume(returning: points)
            }
            store.execute(query)
        }
    }

    // MARK: - Heart rate recovery

    private static func recentHRRecoverySamples(daysBack: Int) async throws -> [HRRecoverySample] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let store = HKHealthStore()
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) else {
            return []
        }
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let mapped = (samples as? [HKQuantitySample])?.map { s in
                    HRRecoverySample(
                        id: s.uuid.uuidString,
                        recordedAt: s.startDate,
                        dropBPM: s.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    )
                } ?? []
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    // MARK: - HRV (single 7-day average — kept for backward compat)

    private static func latestHRV() async throws -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let store = HKHealthStore()

        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date())

        return try await withCheckedThrowingContinuation { continuation in
            let statsQuery = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let value = stats?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: value)
            }
            store.execute(statsQuery)
        }
    }

    // MARK: - Sleep

    private static func recentSleepHours(nights: Int) async throws -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let store = HKHealthStore()

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }
        let startDate = Calendar.current.date(byAdding: .day, value: -nights, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let hkQuery = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                let asleepValues: [HKCategoryValueSleepAnalysis] = [.asleepCore, .asleepDeep, .asleepREM]
                let totalSeconds = sleepSamples
                    .filter { sample in
                        asleepValues.contains(HKCategoryValueSleepAnalysis(rawValue: sample.value)!)
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let avgHours = totalSeconds / 3600.0 / Double(max(nights, 1))
                continuation.resume(returning: avgHours)
            }
            store.execute(hkQuery)
        }
    }

    // MARK: - Recent workouts

    private static func recentWorkouts(since: Date) async throws -> [HKWorkoutSummary] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let store = HKHealthStore()
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForSamples(withStart: since, end: Date()),
        ])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let hkQuery = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let summaries = (samples as? [HKWorkout])?.map { workout in
                    HKWorkoutSummary(
                        id: workout.uuid.uuidString,
                        startDate: workout.startDate,
                        duration: workout.duration,
                        distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                    )
                } ?? []
                continuation.resume(returning: summaries)
            }
            store.execute(hkQuery)
        }
    }
}
