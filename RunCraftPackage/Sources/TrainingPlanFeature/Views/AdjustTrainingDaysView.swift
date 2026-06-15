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
                    Text("Training Days")
                } footer: {
                    Text("Changes apply to next week onward — this week's plan stays as-is.")
                }
            }
            .navigationTitle("Adjust Training Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveTapped) }
                        .bold()
                        .disabled(!store.hasChanged)
                }
            }
        }
    }
}
