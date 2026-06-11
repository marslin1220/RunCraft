import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine

struct EditStepSheet: View {
    @Bindable var store: StoreOf<EditStep>
    @FetchOne(WorkoutTemplate.none) var currentVDOTPlaceholder: WorkoutTemplate?
    @FetchOne var latestGoal: RaceGoal?

    private var currentVDOT: Double {
        latestGoal?.currentVDOT ?? 40
    }

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
                        TimeWheelPicker(minutes: $store.minutes, seconds: $store.seconds)
                    }
                }

                Section {
                    Picker("Alert", selection: $store.alertKind) {
                        ForEach(EditStep.State.AlertKind.allCases, id: \.self) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch store.alertKind {
                    case .none:
                        Text("No pace or heart-rate target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .pace:
                        paceFields
                    case .heartRate:
                        heartRateFields
                    }
                } header: {
                    Text("Alert")
                } footer: {
                    if store.alertKind == .pace {
                        Text("Tap a zone to fill from your current VDOT (\(Int(currentVDOT.rounded()))).")
                            .font(.caption)
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

    // MARK: - Pace alert UI

    private var paceFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                paceField(label: "Min", value: $store.paceMinSec)
                paceField(label: "Max", value: $store.paceMaxSec)
            }

            // Zone quick-fill row
            HStack(spacing: 6) {
                ForEach(PaceZoneName.allCases, id: \.self) { zone in
                    Button {
                        let alert = StepAlert.paceZone(zone, vdot: currentVDOT)
                        if case let .paceRange(lo, hi) = alert {
                            store.paceMinSec = lo
                            store.paceMaxSec = hi
                        }
                    } label: {
                        Text(zone.letter)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.8, green: 1, blue: 0).opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.8, green: 1, blue: 0).opacity(0.5), lineWidth: 1)
                            )
                            .foregroundStyle(Color(red: 0.8, green: 1, blue: 0))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func paceField(label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField("min", value: value.minutesPart, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 36)
                Text(":").foregroundStyle(.secondary)
                TextField("sec", value: value.secondsPart, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.leading)
                    .frame(width: 36)
                Text(verbatim: "/km").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - HR alert UI

    private var heartRateFields: some View {
        HStack(spacing: 14) {
            hrField(label: "Min", value: $store.hrMin)
            hrField(label: "Max", value: $store.hrMax)
        }
    }

    private func hrField(label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField("bpm", value: value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                Text("bpm").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Int convenience for MM:SS bindings

extension Int {
    /// Treat self as total seconds — read/write the minutes component.
    fileprivate var minutesPart: Int {
        get { self / 60 }
        set { self = newValue * 60 + (self % 60) }
    }
    /// Treat self as total seconds — read/write the seconds (0–59) component.
    fileprivate var secondsPart: Int {
        get { self % 60 }
        set { self = (self / 60) * 60 + newValue }
    }
}
