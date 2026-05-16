import Foundation
import HealthKit

enum LiveHealthKitClient {
    static func make() -> HealthKitClient {
        HealthKitClient(
            requestAuthorization: {
                guard HKHealthStore.isHealthDataAvailable() else { return }
                let store = HKHealthStore()
                let types: Set<HKObjectType> = [
                    HKObjectType.workoutType(),
                    HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
                    HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                ]
                try await store.requestAuthorization(toShare: [], read: types)
            },
            bestRaceTime: { distance in
                try await bestRaceTime(for: distance)
            },
            latestHRV: {
                try await latestHRV()
            },
            recentSleepHours: { nights in
                try await recentSleepHours(nights: nights)
            }
        )
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

    // MARK: - HRV

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
}
