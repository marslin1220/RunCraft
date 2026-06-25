import ComposableArchitecture
import SwiftUI

public struct AdjustTrainingDaysView: View {
    @Bindable public var store: StoreOf<AdjustTrainingDays>

    public init(store: StoreOf<AdjustTrainingDays>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TrainingDaysGrid(store: store.scope(state: \.trainingDaysInput, action: \.trainingDaysInput))
                } header: {
                    Text("Training Days", bundle: .module)
                } footer: {
                    Text("Changes apply to next week onward — this week's plan stays as-is.", bundle: .module)
                }
            }
            .navigationTitle(Text("Adjust Training Days", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { store.send(.cancelTapped) } label: { Text("Cancel", bundle: .module) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.saveTapped) } label: { Text("Save", bundle: .module) }
                        .bold()
                        .disabled(!store.hasChanged)
                }
            }
        }
    }
}
