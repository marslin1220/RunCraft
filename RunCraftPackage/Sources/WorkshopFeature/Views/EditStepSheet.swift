import ComposableArchitecture
import RunCraftModels
import SwiftUI

struct EditStepSheet: View {
    @Bindable var store: StoreOf<EditStep>

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Step", selection: $store.step.kind) {
                        ForEach(StepKind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                }

                Section("Goal") {
                    Picker("Type", selection: $store.goalUnit) {
                        ForEach(EditStep.State.GoalUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch store.goalUnit {
                    case .openEnded:
                        Text("Runs until you tap Lap").foregroundStyle(.secondary)
                    case .distance:
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("metres", value: $store.distanceMetres, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text("m").foregroundStyle(.secondary)
                        }
                    case .time:
                        HStack {
                            Text("Time")
                            Spacer()
                            TextField("min", value: $store.minutes, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                            Text("min").foregroundStyle(.secondary)
                            TextField("sec", value: $store.seconds, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 40)
                            Text("sec").foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Pace Alert") {
                    Picker("Zone", selection: paceBinding) {
                        Text("None").tag(SessionType?.none)
                        ForEach(SessionType.allCases.filter { $0 != .rest }, id: \.self) { z in
                            Text(z.displayName).tag(SessionType?.some(z))
                        }
                    }
                }
            }
            .navigationTitle("Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveTapped) }
                        .bold()
                        .disabled(!store.isValid)
                }
            }
        }
    }

    private var paceBinding: Binding<SessionType?> {
        Binding(
            get: {
                if case let .pace(z) = store.step.alert { return z }
                return nil
            },
            set: { new in
                if let z = new {
                    store.step.alert = .pace(z)
                } else {
                    store.step.alert = nil
                }
            }
        )
    }
}
