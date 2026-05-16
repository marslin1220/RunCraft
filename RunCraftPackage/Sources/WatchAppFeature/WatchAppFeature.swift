import ComposableArchitecture
import RunCraftModels
import SQLiteData

/// Skeleton Watch feature — displays today's planned session.
/// P1: receive live plan pushes via WatchConnectivity.
@Reducer public struct WatchAppFeature {
    @ObservableState public struct State: Equatable {
        public var todaySession: PlannedSession? = nil
        public var isLoading: Bool = false

        public init() {}
    }

    public enum Action {
        case onAppear
        case todaySessionLoaded(PlannedSession?)
    }

    @Dependency(\.defaultDatabase) var database

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let session = try? await database.read { db -> PlannedSession? in
                        let weekday = Calendar.current.component(.weekday, from: Date())
                        let dayOfWeek = weekday == 1 ? 7 : weekday - 1  // convert to Mon=1
                        return try PlannedSession
                            .where { $0.dayOfWeek.eq(dayOfWeek) }
                            .fetchOne(db)
                    }
                    await send(.todaySessionLoaded(session))
                }

            case let .todaySessionLoaded(session):
                state.isLoading = false
                state.todaySession = session
                return .none
            }
        }
    }
}
