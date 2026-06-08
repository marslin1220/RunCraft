import ComposableArchitecture
import RunCraftModels
import SwiftUI

struct EditRepeatGroupSheet: View {
    @Bindable var store: StoreOf<EditRepeatGroup>

    var body: some View {
        NavigationStack {
            Form {
                Section("Repetitions") {
                    Stepper(value: $store.group.iterations, in: 1...30) {
                        HStack {
                            Text("Iterations")
                            Spacer()
                            Text("\(store.group.iterations)×")
                                .foregroundStyle(Color(red: 0.8, green: 1, blue: 0))
                        }
                    }
                }

                if !store.availableSteps.isEmpty {
                    Section {
                        ForEach(store.availableSteps) { step in
                            availableStepRow(step)
                        }
                    } header: {
                        Text("Include from workout")
                    } footer: {
                        Text("Tap to copy an existing step into this repeat. The copy is independent — editing it doesn't change the original.")
                            .font(.caption)
                    }
                }

                Section {
                    if store.group.steps.isEmpty {
                        Text("No steps yet — tap an option above, or add a new step.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.group.steps) { step in
                            Button {
                                store.send(.editStepTapped(step.id))
                            } label: {
                                stepInRepeatRow(step)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.send(.deleteStep(id: step.id))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }

                    Button {
                        store.send(.addStepTapped)
                    } label: {
                        Label("Add step", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color(red: 0.8, green: 1, blue: 0))
                    }
                } header: {
                    Text("Steps in repeat")
                }
            }
            .navigationTitle("Edit Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveTapped) }.bold()
                }
            }
            .sheet(item: $store.scope(state: \.editingStep, action: \.editingStep)) { childStore in
                EditStepSheet(store: childStore)
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func availableStepRow(_ step: WorkoutStep) -> some View {
        let included = store.group.steps.contains { isCopyOf($0, source: step) }
        Button {
            store.send(.toggleAvailableStep(step))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(included ? Color(red: 0.8, green: 1, blue: 0) : .secondary)
                Image(systemName: step.kind.symbolName).frame(width: 18)
                Text(step.kind.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                Text(step.goal.displayText).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func stepInRepeatRow(_ step: WorkoutStep) -> some View {
        HStack(spacing: 10) {
            Image(systemName: step.kind.symbolName).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.kind.displayName).foregroundStyle(.primary)
                if let alert = step.alert {
                    Text(alert.displayText).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(step.goal.displayText).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func isCopyOf(_ a: WorkoutStep, source b: WorkoutStep) -> Bool {
        a.kind == b.kind && a.goal == b.goal && a.alert == b.alert
    }
}
