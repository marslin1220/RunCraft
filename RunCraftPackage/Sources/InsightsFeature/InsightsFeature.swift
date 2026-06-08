import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData
import VDOTEngine

/// Insights tab reducer. Loads VDOT history and recent completed workouts,
/// then exposes derived views (weekly mileage, predicted race times) for
/// the SwiftUI layer to render with Swift Charts.
@Reducer public struct InsightsFeature {
    @ObservableState public struct State {
        public var currentVDOT: Double = 0
        public var snapshots: [VDOTSnapshot] = []
        public var recentWorkouts: [CompletedWorkout] = []
        public var isLoading: Bool = false

        public init() {}

        /// Aggregates the last 8 weeks of completed-workout distance into
        /// week-bucketed totals. Ordered oldest → newest for chart x-axis.
        public var weeklyMileage: [WeeklyMileage] {
            WeeklyMileage.bucket(workouts: recentWorkouts, weekCount: 8)
        }

        public var predictedTimes: [PredictedRace] {
            guard currentVDOT > 0 else { return [] }
            let distances: [RaceDistance] = [.fiveK, .tenK, .halfMarathon, .custom(42.195)]
            return distances.map { distance in
                let seconds = VDOTCalculator.predictedTime(
                    distanceMeters: distance.metres,
                    vdot: currentVDOT
                )
                return PredictedRace(distance: distance, totalSeconds: seconds)
            }
        }
    }

    public enum Action {
        case onAppear
        case dataLoaded(
            currentVDOT: Double,
            snapshots: [VDOTSnapshot],
            recentWorkouts: [CompletedWorkout]
        )
    }

    @Dependency(\.defaultDatabase) var database

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [database] send in
                    let (vdot, snapshots, workouts) = try await database.read {
                        db -> (Double, [VDOTSnapshot], [CompletedWorkout]) in
                        let goal = try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                        let snaps = try VDOTSnapshot
                            .order { $0.recordedAt.asc() }
                            .fetchAll(db)
                        let workouts = try CompletedWorkout
                            .order { $0.completedAt.desc() }
                            .fetchAll(db)
                        return (goal?.currentVDOT ?? 0, snaps, workouts)
                    }
                    await send(.dataLoaded(
                        currentVDOT: vdot,
                        snapshots: snapshots,
                        recentWorkouts: workouts
                    ))
                }

            case let .dataLoaded(vdot, snapshots, workouts):
                state.isLoading = false
                state.currentVDOT = vdot
                state.snapshots = snapshots
                state.recentWorkouts = workouts
                return .none
            }
        }
    }
}

// MARK: - Derived models

public struct WeeklyMileage: Identifiable, Equatable, Sendable {
    public let id: Date          // week-start date
    public let weekStart: Date
    public let totalKm: Double

    /// Buckets `workouts` into the most recent `weekCount` weeks ending on
    /// the current week. Empty weeks contribute a zero bar (so the chart
    /// has a stable x-axis instead of skipping weeks).
    static func bucket(workouts: [CompletedWorkout], weekCount: Int) -> [WeeklyMileage] {
        let calendar = Calendar.current
        let now = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }
        return (0..<weekCount).reversed().compactMap { offset -> WeeklyMileage? in
            guard let weekStart = calendar.date(
                byAdding: .weekOfYear,
                value: -offset,
                to: currentWeekStart
            ) else { return nil }
            guard let weekEnd = calendar.date(
                byAdding: .weekOfYear,
                value: 1,
                to: weekStart
            ) else { return nil }
            let totalKm = workouts
                .filter { $0.completedAt >= weekStart && $0.completedAt < weekEnd }
                .reduce(0.0) { $0 + $1.actualDistanceKm }
            return WeeklyMileage(id: weekStart, weekStart: weekStart, totalKm: totalKm)
        }
    }
}

public struct PredictedRace: Identifiable, Equatable, Sendable {
    public var id: String { distance.displayName }
    public let distance: RaceDistance
    public let totalSeconds: TimeInterval

    public var formatted: String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
