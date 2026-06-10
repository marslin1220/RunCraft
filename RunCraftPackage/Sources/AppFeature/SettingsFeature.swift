import ComposableArchitecture
import Foundation
import VDOTEngine

@Reducer public struct Settings {
    @ObservableState public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case onAppear
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}
