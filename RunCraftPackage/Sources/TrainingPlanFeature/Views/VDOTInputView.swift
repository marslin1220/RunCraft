import ComposableArchitecture
import DesignSystem
import HealthKitClient
import RunCraftModels
import SwiftUI
import VDOTEngine

/// VDOT header + manual race-time entry + HealthKit auto-detect, shared by
/// `SetupRaceGoalView` and `SetupVDOTView`.
public struct VDOTInputSections: View {
    @Bindable var store: StoreOf<VDOTInput>
    @State private var showVDOTInfo = false

    public init(store: StoreOf<VDOTInput>) {
        self.store = store
    }

    public var body: some View {
        Group {
            Section {
            } header: {
                HStack(spacing: 6) {
                    Text("Fitness Level (VDOT)", bundle: .module)
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
                Picker(selection: $store.manualDistance) {
                    ForEach(RaceDistanceQuery.allCases, id: \.self) { d in
                        Text(d.displayName).tag(d)
                    }
                } label: {
                    Text("Distance", bundle: .module)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Finish time input — wheel picker for consistency
                // with the Workshop edit-step sheet, avoids the
                // tiny number-pad TextFields that were mis-tap-prone.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Finish time", bundle: .module)
                        .foregroundStyle(.primary)
                    TimeWheelPicker(
                        minutes: $store.manualMinutes,
                        seconds: $store.manualSeconds,
                        minutesRange: 0...240
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Live VDOT result from manual entry
                if store.detectedVDOT == nil, let vdot = store.calculatedVDOT {
                    HStack {
                        Text("Your VDOT", bundle: .module)
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
                        Label { Text("Auto-detect from HealthKit", bundle: .module) } icon: { Image(systemName: "heart.fill") }
                        Spacer()
                        if store.isDetectingVDOT { ProgressView() }
                    }
                }
                .disabled(store.isDetectingVDOT)

                if let vdot = store.detectedVDOT {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best detected VDOT", bundle: .module)
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
                Text("Or auto-detect", bundle: .module)
            } footer: {
                Text("Scans your HealthKit running history for a best 5K, 10K or half marathon time.", bundle: .module)
                    .font(.caption)
            }
        }
    }
}

/// A read-only preview of the five Jack Daniels training pace zones,
/// derived from an already-resolved VDOT.
public struct PaceZonesPreviewSection: View {
    let zones: PaceZones
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    public init(zones: PaceZones) {
        self.zones = zones
    }

    public var body: some View {
        Section {
            PaceZoneRow(label: "E  Easy",       pace: zones.easy.formatted(unit: paceUnit),       color: Color(hex: "#4CAF50"))
            PaceZoneRow(label: "M  Marathon",   pace: zones.marathon.formatted(unit: paceUnit),   color: Color(hex: "#2196F3"))
            PaceZoneRow(label: "T  Threshold",  pace: zones.threshold.formatted(unit: paceUnit),  color: Color(hex: "#FFC107"))
            PaceZoneRow(label: "I  Interval",   pace: zones.interval.formatted(unit: paceUnit),   color: Color(hex: "#FF5722"))
            PaceZoneRow(label: "R  Repetition", pace: zones.repetition.formatted(unit: paceUnit), color: Color(hex: "#F44336"))
        } header: {
            Text("Your Training Paces", bundle: .module)
        }
    }
}

struct VDOTInfoPopover: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("What is VDOT?", bundle: .module)
                            .font(.headline)
                        Text("VDOT is a number that represents your current running fitness, developed by coach Jack Daniels. It is calculated from a recent race result and reflects the effective VO₂max you demonstrated on race day.", bundle: .module)
                    }

                    Divider()

                    Group {
                        Text("How is it calculated?", bundle: .module)
                            .font(.headline)
                        Text("Enter a recent race time (e.g. 5K in 25 min) and the app uses the Jack Daniels formula to derive your VDOT. A faster race time = higher VDOT.", bundle: .module)
                    }

                    Divider()

                    Group {
                        Text("Typical VDOT ranges", bundle: .module)
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            RangeRow(range: "30 – 39", label: String(localized: "Beginner", bundle: .module))
                            RangeRow(range: "40 – 49", label: String(localized: "Recreational", bundle: .module))
                            RangeRow(range: "50 – 59", label: String(localized: "Competitive club", bundle: .module))
                            RangeRow(range: "60 – 75", label: String(localized: "Elite amateur", bundle: .module))
                            RangeRow(range: "76+",     label: String(localized: "Professional", bundle: .module))
                        }
                    }

                    Divider()

                    Group {
                        Text("Why does it matter?", bundle: .module)
                            .font(.headline)
                        Text("RunCraft uses your VDOT to set your five training pace zones — Easy, Marathon, Threshold, Interval, and Repetition — so every session targets the right physiological adaptation.", bundle: .module)
                    }
                }
                .padding()
            }
            .navigationTitle(Text("About VDOT", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done", bundle: .module) }
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

struct PaceZoneRow: View {
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
