import ComposableArchitecture
import RunCraftModels
import SwiftUI

public struct SetupRaceGoalView: View {
    @Bindable public var store: StoreOf<SetupRaceGoal>

    public init(store: StoreOf<SetupRaceGoal>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Race Goal") {
                    TextField("Goal name (e.g. Sun Moon Lake 29K)", text: $store.goalName)
                    DatePicker("Race date", selection: $store.targetDate, displayedComponents: .date)
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("km", value: $store.distanceKm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("km")
                    }
                }

                Section("Fitness Level (VDOT)") {
                    Button {
                        store.send(.detectVDOTTapped)
                    } label: {
                        HStack {
                            Label("Auto-detect from HealthKit", systemImage: "heart.fill")
                            Spacer()
                            if store.isDetectingVDOT {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(store.isDetectingVDOT)

                    if let vdot = store.detectedVDOT {
                        HStack {
                            Text("Detected VDOT")
                            Spacer()
                            Text(vdot, format: .number.precision(.fractionLength(1)))
                                .bold()
                                .foregroundStyle(Color(hex: "#CCFF00"))
                        }
                    }

                    HStack {
                        Text("Or enter manually")
                        Spacer()
                        TextField("30–85", text: $store.manualVDOTInput)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                if let zones = store.paceZones {
                    Section("Your Training Paces") {
                        PaceZoneRow(label: "E  Easy",       pace: zones.easy.formatted(),       color: Color(hex: "#4CAF50"))
                        PaceZoneRow(label: "M  Marathon",   pace: zones.marathon.formatted(),   color: Color(hex: "#2196F3"))
                        PaceZoneRow(label: "T  Threshold",  pace: zones.threshold.formatted(),  color: Color(hex: "#FFC107"))
                        PaceZoneRow(label: "I  Interval",   pace: zones.interval.formatted(),   color: Color(hex: "#FF5722"))
                        PaceZoneRow(label: "R  Repetition", pace: zones.repetition.formatted(), color: Color(hex: "#F44336"))
                    }
                }
            }
            .navigationTitle("New Race Goal")
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
}

private struct PaceZoneRow: View {
    let label: String
    let pace: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(pace)
                .foregroundStyle(.secondary)
        }
    }
}
