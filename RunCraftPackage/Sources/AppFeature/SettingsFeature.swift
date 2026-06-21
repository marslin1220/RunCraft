import ComposableArchitecture
import Foundation
import VDOTEngine

@Reducer public struct Settings {
    @ObservableState public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case onAppear
        case delegate(Delegate)

        public enum Delegate {
            case openTrainingDays
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onAppear, .delegate:
                return .none
            }
        }
    }
}
