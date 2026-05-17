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
                            Text("\(store.group.iterations)×").foregroundStyle(Color(red: 0.8, green: 1, blue: 0))
                        }
                    }
                }

                Section("Steps in repeat") {
                    if store.group.steps.isEmpty {
                        Text("No steps yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.group.steps) { step in
                            HStack(spacing: 10) {
                                Image(systemName: step.kind.symbolName)
                                    .frame(width: 18)
                                Text(step.kind.displayName)
                                Spacer()
                                Text(step.goal.displayText).foregroundStyle(.secondary)
                                Button {
                                    store.send(.deleteStep(id: step.id))
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Menu {
                        ForEach(StepKind.allCases, id: \.self) { kind in
                            Button {
                                store.send(.addStepTapped(kind))
                            } label: {
                                Label(kind.displayName, systemImage: kind.symbolName)
                            }
                        }
                    } label: {
                        Label("Add step", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color(red: 0.8, green: 1, blue: 0))
                    }
                }
            }
            .navigationTitle("Edit Repeat Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveTapped) }.bold()
                }
            }
        }
    }
}
