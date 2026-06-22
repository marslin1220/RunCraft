import ComposableArchitecture
import Foundation
import HealthKitClient
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
        public var vo2MaxSamples: [VO2MaxSample] = []
        public var recentWorkouts: [CompletedWorkout] = []
        public var selectedTrend: TrendKind = .vdot
        public var isLoading: Bool = false
        public var hrvSamples: [HRVSample] = []
        public var restingHRSamples: [RestingHRSample] = []

        public init() {}

        /// Hero number for the currently selected trend (rendered above the
        /// chart). Returns nil when there's no data yet so the view can
        /// substitute a placeholder.
        public var heroValue: Double? {
            switch selectedTrend {
            case .vdot:
                return currentVDOT > 0 ? currentVDOT : nil
            case .vo2Max:
                return vo2MaxSamples.last?.vo2Max
            case .delta:
                return deltaSeries.last?.value
            case .threshold:
                return thresholdSeries.last?.value
            }
        }

        /// T-pace midpoint (s/km) derived from each VDOT snapshot. Stored in
        /// the same TrendPoint wrapper as the other series so the chart layer
        /// is uniform. Lower value = faster threshold pace = better fitness.
        public var thresholdSeries: [TrendPoint] {
            snapshots.map { snap in
                let mid = VDOTCalculator.paceZones(vdot: snap.vdot).threshold
                let midpoint = (mid.lower + mid.upper) / 2
                return TrendPoint(id: snap.id.uuidString, date: snap.recordedAt, value: midpoint)
            }
        }

        /// Time-aligned (VDOT − VO2max) series. For each VDOT snapshot at
        /// date d, picks the most-recent VO2max sample at or before d and
        /// emits the difference. Skips snapshots that have no VO2max
        /// counterpart yet — better than back-filling with zeros which
        /// would look like real data.
        public var deltaSeries: [TrendPoint] {
            guard !vo2MaxSamples.isEmpty else { return [] }
            let vo2Sorted = vo2MaxSamples.sorted { $0.recordedAt < $1.recordedAt }
            return snapshots.compactMap { snap -> TrendPoint? in
                guard let nearest = vo2Sorted.last(where: { $0.recordedAt <= snap.recordedAt }) else {
                    return nil
                }
                return TrendPoint(
                    id: snap.id.uuidString,
                    date: snap.recordedAt,
                    value: snap.vdot - nearest.vo2Max
                )
            }
        }

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

    /// Which series the fitness-trend card is currently showing. Drives the
    /// segmented picker, the hero number, and the chart data + colour.
    public enum TrendKind: String, CaseIterable, Equatable, Sendable {
        case vdot
        case vo2Max
        case delta
        case threshold

        public var label: String {
            switch self {
            case .vdot:      "VDOT"
            case .vo2Max:    "VO₂max"
            case .delta:     "Δ"
            case .threshold: "T-pace"
            }
        }

        public var caption: String {
            switch self {
            case .vdot:      "Drives your plan"
            case .vo2Max:    "Apple Watch estimate"
            case .delta:     "VDOT − VO₂max"
            case .threshold: "Lactate threshold pace"
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case dataLoaded(
            currentVDOT: Double,
            snapshots: [VDOTSnapshot],
            recentWorkouts: [CompletedWorkout],
            vo2MaxSamples: [VO2MaxSample],
            hrvSamples: [HRVSample],
            restingHRSamples: [RestingHRSample]
        )
        case setUpVDOTTapped
        case delegate(Delegate)

        public enum Delegate {
            /// Parent (AppFeature) should switch to the Plan tab and open
            /// "Set Up VDOT" — there's no race goal yet, so nothing here
            /// (pace zones, predictions) can be computed.
            case setUpVDOTTapped
        }
    }

    @Dependency(\.defaultDatabase) var database
    @Dependency(\.healthKitClient) var healthKitClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                state.isLoading = true
                return .run { [database, healthKitClient] send in
                    async let dbLoad: (Double, [VDOTSnapshot], [CompletedWorkout]) = database.read {
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
                    // HK queries are optional — not every runner has a Watch or
                    // has granted access. Failures here must not block the load.
                    async let vo2Load: [VO2MaxSample] = (try? await healthKitClient.recentVO2MaxSamples(180)) ?? []
                    async let hrvLoad: [HRVSample] = (try? await healthKitClient.recentHRVSamples(90)) ?? []
                    async let restingHRLoad: [RestingHRSample] = (try? await healthKitClient.recentRestingHRSamples(90)) ?? []

                    let (vdot, snapshots, workouts) = try await dbLoad
                    let vo2 = await vo2Load
                    let hrv = await hrvLoad
                    let restingHR = await restingHRLoad

                    await send(.dataLoaded(
                        currentVDOT: vdot,
                        snapshots: snapshots,
                        recentWorkouts: workouts,
                        vo2MaxSamples: vo2,
                        hrvSamples: hrv,
                        restingHRSamples: restingHR
                    ))
                }

            case let .dataLoaded(vdot, snapshots, workouts, vo2, hrv, restingHR):
                state.isLoading = false
                state.currentVDOT = vdot
                state.snapshots = snapshots
                state.recentWorkouts = workouts
                state.vo2MaxSamples = vo2
                state.hrvSamples = hrv
                state.restingHRSamples = restingHR
                return .none

            case .setUpVDOTTapped:
                return .send(.delegate(.setUpVDOTTapped))

            case .delegate:
                return .none
            }
        }
    }
}

/// Lightweight point used by the deltaSeries / VO2max chart. Identifiable
/// + Equatable so Swift Charts can diff frames cheaply.
public struct TrendPoint: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let value: Double

    public init(id: String, date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
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
        return PaceFormatting.minutesSeconds(totalSeconds)
    }
}
