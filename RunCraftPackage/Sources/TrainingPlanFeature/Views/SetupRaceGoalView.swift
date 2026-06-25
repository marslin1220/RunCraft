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
                    TextField(text: $store.goalName) { Text("Goal name (e.g. Sun Moon Lake 29K)", bundle: .module) }
                        .submitLabel(.next)
                    DatePicker(selection: $store.targetDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date) {
                        Text("Race date", bundle: .module)
                    }
                    HStack {
                        Text("Distance", bundle: .module)
                        Spacer()
                        TextField("km", value: $store.distanceKm, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(verbatim: "km")
                            .foregroundStyle(.secondary)
                        Stepper(value: $store.distanceKm, in: 1...100, step: 1) {
                            Text("Distance", bundle: .module)
                        }
                        .labelsHidden()
                    }
                } header: {
                    Text("Race Goal", bundle: .module)
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

                Section {
                    TrainingDaysGrid(store: store.scope(state: \.trainingDaysInput, action: \.trainingDaysInput))
                } header: {
                    Text("Training Days", bundle: .module)
                } footer: {
                    Text("Pick the days you can train. We'll place your long run, hard sessions, and rest days around them.", bundle: .module)
                }
            }
            .navigationTitle(store.editingId == nil ? Text("New Race Goal", bundle: .module) : Text("Edit Race Goal", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { store.send(.cancelButtonTapped) } label: { Text("Cancel", bundle: .module) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.saveButtonTapped) } label: { Text("Save", bundle: .module) }
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
            return String(localized: "Enter a goal name to continue.", bundle: .module)
        }
        if store.vdotInput.effectiveVDOT == nil {
            return String(localized: "Enter a recent race time, or tap Auto-detect, so we can calculate your VDOT.", bundle: .module)
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
