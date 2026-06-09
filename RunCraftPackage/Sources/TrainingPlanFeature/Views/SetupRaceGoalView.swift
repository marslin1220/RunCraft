import ComposableArchitecture
import DesignSystem
import HealthKitClient
import RunCraftModels
import SwiftUI

public struct SetupRaceGoalView: View {
    @Bindable public var store: StoreOf<SetupRaceGoal>
    @State private var showVDOTInfo = false

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
                        Text("km")
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

                Section {
                } header: {
                    HStack(spacing: 6) {
                        Text("Fitness Level (VDOT)")
                        Button {
                            showVDOTInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showVDOTInfo, arrowEdge: .top) {
                            VDOTInfoPopover()
                        }
                    }
                } footer: {
                    EmptyView()
                }
                Section {
                    // Distance picker
                    Picker("Distance", selection: $store.manualDistance) {
                        ForEach(RaceDistanceQuery.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    // Finish time input
                    HStack {
                        Text("Finish time")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(store.manualDistance == .halfMarathon ? "75" : "25", text: $store.manualMinutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 44)
                        Text("min")
                            .foregroundStyle(.secondary)
                        TextField("00", text: $store.manualSeconds)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 36)
                        Text("sec")
                            .foregroundStyle(.secondary)
                    }

                    // Live VDOT result from manual entry
                    if store.detectedVDOT == nil, let vdot = store.calculatedVDOT {
                        HStack {
                            Text("Your VDOT")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(vdot, format: .number.precision(.fractionLength(1)))
                                .bold()
                                .foregroundStyle(Color.brand.accent)
                                .contentTransition(.numericText())
                        }
                    }
                }

                Section {
                    // HealthKit auto-detect
                    Button {
                        store.send(.detectVDOTTapped)
                    } label: {
                        HStack {
                            Label("Auto-detect from HealthKit", systemImage: "heart.fill")
                            Spacer()
                            if store.isDetectingVDOT { ProgressView() }
                        }
                    }
                    .disabled(store.isDetectingVDOT)

                    if let vdot = store.detectedVDOT {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Best detected VDOT")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(vdot, format: .number.precision(.fractionLength(1)))
                                    .bold()
                                    .foregroundStyle(Color.brand.accent)
                            }
                            Spacer()
                            Button {
                                store.send(.clearDetectedVDOTTapped)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Or auto-detect")
                } footer: {
                    Text("Scans your HealthKit running history for a best 5K, 10K or half marathon time.")
                        .font(.caption)
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
        if store.effectiveVDOT == nil {
            return "Enter a recent race time, or tap Auto-detect, so we can calculate your VDOT."
        }
        return ""
    }
}

private struct VDOTInfoPopover: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("What is VDOT?")
                            .font(.headline)
                        Text("VDOT is a number that represents your current running fitness, developed by coach Jack Daniels. It is calculated from a recent race result and reflects the effective VO₂max you demonstrated on race day.")
                    }

                    Divider()

                    Group {
                        Text("How is it calculated?")
                            .font(.headline)
                        Text("Enter a recent race time (e.g. 5K in 25 min) and the app uses the Jack Daniels formula to derive your VDOT. A faster race time = higher VDOT.")
                    }

                    Divider()

                    Group {
                        Text("Typical VDOT ranges")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            RangeRow(range: "30 – 39", label: "Beginner")
                            RangeRow(range: "40 – 49", label: "Recreational")
                            RangeRow(range: "50 – 59", label: "Competitive club")
                            RangeRow(range: "60 – 75", label: "Elite amateur")
                            RangeRow(range: "76+",     label: "Professional")
                        }
                    }

                    Divider()

                    Group {
                        Text("Why does it matter?")
                            .font(.headline)
                        Text("RunCraft uses your VDOT to set your five training pace zones — Easy, Marathon, Threshold, Interval, and Repetition — so every session targets the right physiological adaptation.")
                    }
                }
                .padding()
            }
            .navigationTitle("About VDOT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private struct RangeRow: View {
        let range: String
        let label: String
        var body: some View {
            HStack {
                Text(range)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                Text(label)
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

#Preview {
    SetupRaceGoalView(
        store: .init(initialState: SetupRaceGoal.State()) {
            SetupRaceGoal()
        }
    )
}
