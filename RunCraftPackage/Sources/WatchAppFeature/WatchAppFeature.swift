import AppleWatchSync
import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData
import VDOTEngine
#if canImport(WorkoutKit)
import WorkoutKit
#endif

/// On-wrist reducer for RunCraft.
///
/// Loads today's PlannedSession + current VDOT once on appear, converts
/// the session to a WorkoutKit `WorkoutPlan` on demand, and pushes it to
/// the native Workout app via `WorkoutPlan.openInWorkoutApp()`.
@Reducer public struct WatchAppFeature {
    @ObservableState public struct State {
        public var todaySession: PlannedSession? = nil
        public var currentVDOT: Double = 0
        public var isLoading: Bool = false
        public var lastError: String? = nil

        public init() {}

        public var todayPaceRange: PaceZones.PaceRange? {
            guard let zone = todaySession?.targetPaceZone, currentVDOT > 0 else { return nil }
            return VDOTCalculator.paceRange(for: zone, vdot: currentVDOT)
        }
    }

    public enum Action {
        case onAppear
        case dataLoaded(todaySession: PlannedSession?, currentVDOT: Double)
        case startWorkoutTapped
        case startWorkoutResponse(Result<Void, any Error>)
    }

    @Dependency(\.defaultDatabase) var database

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [database] send in
                    let (session, vdot) = try await database.read { db -> (PlannedSession?, Double) in
                        let weeks = try TrainingWeek.all.fetchAll(db)
                        let weekday = Calendar.current.component(.weekday, from: Date())
                        let dayOfWeek = weekday == 1 ? 7 : weekday - 1
                        let session: PlannedSession?
                        if let week = TrainingWeek.current(in: weeks) {
                            session = try PlannedSession
                                .where { $0.weekId.eq(week.id) }
                                .where { $0.dayOfWeek.eq(dayOfWeek) }
                                .fetchOne(db)
                        } else {
                            session = nil
                        }
                        let goal = try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                        return (session, goal?.currentVDOT ?? 0)
                    }
                    await send(.dataLoaded(todaySession: session, currentVDOT: vdot))
                }

            case let .dataLoaded(session, vdot):
                state.isLoading = false
                state.todaySession = session
                state.currentVDOT = vdot
                return .none

            case .startWorkoutTapped:
                guard let session = state.todaySession, session.sessionType != .rest else {
                    return .none
                }
                let vdot = state.currentVDOT
                state.lastError = nil
                return .run { send in
                    await send(.startWorkoutResponse(Result {
                        let template = PlanSessionAdapter.makeTemplate(from: session, vdot: vdot)
                        #if canImport(WorkoutKit)
                        let plan = try WorkoutPlanBuilder.makePlan(from: template)
                        try await plan.openInWorkoutApp()
                        #else
                        throw WatchError.unsupportedPlatform
                        #endif
                    }))
                }

            case .startWorkoutResponse(.success):
                return .none

            case let .startWorkoutResponse(.failure(error)):
                state.lastError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                return .none
            }
        }
    }
}

public enum WatchError: LocalizedError {
    case unsupportedPlatform
    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform: "WorkoutKit unavailable on this platform."
        }
    }
}
