import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SwiftUI
import VDOTEngine

public struct SetupRaceGoalView: View {
    @Bindable public var store: StoreOf<SetupRaceGoal>

    public init(store: StoreOf<SetupRaceGoal>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Goal name (e.g. Sun Moon Lake 29K)", text: $store.goalName)
                        .submitLabel(.next)
                    DatePicker(
                        "Race date",
                        selection: $store.targetDate,
                        in: Calendar.current.startOfDay(for: Date())...,
                        displayedComponents: .date
                    )
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("km", value: $store.distanceKm, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(verbatim: "km")
                            .foregroundStyle(.secondary)
                        Stepper("Distance", value: $store.distanceKm, in: 1...100, step: 1)
                            .labelsHidden()
                    }
                } header: {
                    Text("Race Goal")
                } footer: {
                    if !store.canSave {
                        Text(saveBlockerMessage)
                            .font(.caption)
                            .foregroundStyle(Color.brand.caution)
                    }
                }

                VDOTInputSections(store: store.scope(state: \.vdotInput, action: \.vdotInput))

                if let zones = store.vdotInput.paceZones {
                    PaceZonesPreviewSection(zones: zones)
                }
            }
            .navigationTitle(store.editingId == nil ? "New Race Goal" : "Edit Race Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelButtonTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveButtonTapped) }
                        .disabled(!store.canSave)
                        .bold()
                }
            }
        }
    }

    /// Explains why Save is disabled. Visible as a section footer so the
    /// user isn't left wondering which field is wrong.
    private var saveBlockerMessage: String {
        if store.goalName.isEmpty {
            return "Enter a goal name to continue."
        }
        if store.vdotInput.effectiveVDOT == nil {
            return "Enter a recent race time, or tap Auto-detect, so we can calculate your VDOT."
        }
        return ""
    }
}

#Preview {
    SetupRaceGoalView(
        store: .init(initialState: SetupRaceGoal.State()) {
            SetupRaceGoal()
        }
    )
}
