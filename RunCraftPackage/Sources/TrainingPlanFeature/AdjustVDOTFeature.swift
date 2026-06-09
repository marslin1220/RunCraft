import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData
import VDOTEngine

/// Lets the runner override their VDOT directly — bypasses the race-time
/// path for cases where they've recalibrated externally or want to
/// experiment with a different intensity. Writes a VDOTSnapshot with
/// source `.manual` so the Insights trend chart shows where the override
/// landed on the timeline.
@Reducer public struct AdjustVDOT {
    @ObservableState public struct State: Equatable {
        public var vdot: Double
        public let originalVDOT: Double

        public init(currentVDOT: Double) {
            self.vdot = currentVDOT
            self.originalVDOT = currentVDOT
        }

        public var paceZones: PaceZones {
            VDOTCalculator.paceZones(vdot: vdot)
        }

        public var hasChanged: Bool { vdot != originalVDOT }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
    }

    @Dependency(\.defaultDatabase) var database
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .saveTapped:
                guard state.hasChanged else {
                    return .run { [dismiss] _ in await dismiss() }
                }
                let vdot = state.vdot
                let snapshot = VDOTSnapshot(vdot: vdot, recordedAt: now, source: .manual)
                return .run { [database, dismiss] _ in
                    try await database.write { db in
                        try RaceGoal.update { $0.currentVDOT = vdot }.execute(db)
                        try VDOTSnapshot.upsert { snapshot }.execute(db)
                    }
                    await dismiss()
                }

            case .cancelTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
