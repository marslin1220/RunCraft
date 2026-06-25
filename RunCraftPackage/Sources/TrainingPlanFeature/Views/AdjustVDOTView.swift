import ComposableArchitecture
import DesignSystem
import SwiftUI
import VDOTEngine

public struct AdjustVDOTView: View {
    @Bindable public var store: StoreOf<AdjustVDOT>
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    public init(store: StoreOf<AdjustVDOT>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(store.vdot, format: .number.precision(.fractionLength(1)))")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.brand.accent)
                                .monospacedDigit()
                            // Acronym — never localized. See LOCALIZATION.md §2.2.
                            Text(verbatim: "VDOT")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        Stepper(
                            "VDOT",
                            value: $store.vdot,
                            in: 30...85,
                            step: 0.5
                        )
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Adjust VDOT", bundle: .module)
                } footer: {
                    if store.hasChanged {
                        let delta = store.vdot - store.originalVDOT
                        let sign = delta > 0 ? "+" : ""
                        Text("Changes by \(sign)\(delta.formatted(.number.precision(.fractionLength(1)))) from \(store.originalVDOT.formatted(.number.precision(.fractionLength(1)))).", bundle: .module)
                            .font(.caption)
                    } else {
                        Text("Use the stepper to adjust. Changes only commit when you tap Save.", bundle: .module)
                            .font(.caption)
                    }
                }

                Section {
                    PacePreviewRow(label: "E  Easy",       range: store.paceZones.easy,       unit: paceUnit)
                    PacePreviewRow(label: "M  Marathon",   range: store.paceZones.marathon,   unit: paceUnit)
                    PacePreviewRow(label: "T  Threshold",  range: store.paceZones.threshold,  unit: paceUnit)
                    PacePreviewRow(label: "I  Interval",   range: store.paceZones.interval,   unit: paceUnit)
                    PacePreviewRow(label: "R  Repetition", range: store.paceZones.repetition, unit: paceUnit)
                } header: {
                    Text("Resulting Paces", bundle: .module)
                }
            }
            .navigationTitle(Text("Adjust VDOT", bundle: .module))
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

private struct PacePreviewRow: View {
    let label: String
    let range: PaceZones.PaceRange
    let unit: PaceUnit

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(range.formatted(unit: unit))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}
