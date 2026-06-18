import ComposableArchitecture
import DesignSystem
import SwiftUI
import VDOTEngine

/// "Set Up VDOT" — for a runner with no race goal who still wants a
/// training plan. Mirrors `SetupRaceGoalView`'s VDOT section but skips the
/// race-goal fields entirely.
public struct SetupVDOTView: View {
    @Bindable public var store: StoreOf<SetupVDOT>

    public init(store: StoreOf<SetupVDOT>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("We'll set up a rolling base training week using your current VDOT — no race goal required.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VDOTInputSections(store: store.scope(state: \.vdotInput, action: \.vdotInput))

                if let zones = store.vdotInput.paceZones {
                    PaceZonesPreviewSection(zones: zones)
                }

                Section {
                    TrainingDaysGrid(store: store.scope(state: \.trainingDaysInput, action: \.trainingDaysInput))
                } header: {
                    Text("Training Days")
                } footer: {
                    Text("Choose the days you're available to train. The schedule will be built around these days.")
                }
            }
            .navigationTitle("Set Up VDOT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelButtonTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveButtonTapped) }
                        .disabled(store.vdotInput.effectiveVDOT == nil)
                        .bold()
                }
            }
        }
    }
}

#Preview {
    SetupVDOTView(
        store: .init(initialState: SetupVDOT.State()) {
            SetupVDOT()
        }
    )
}
