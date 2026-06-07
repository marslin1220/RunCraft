import ComposableArchitecture
import RunCraftModels
import SwiftUI

public struct WorkoutEditorView: View {
    @Bindable public var store: StoreOf<WorkoutEditor>

    public init(store: StoreOf<WorkoutEditor>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            TemplateNameBar(name: $store.templateName, status: store.saveStatus)
            if store.blocks.isEmpty {
                EmptyWorkshopPrompt()
            } else {
                blockList
            }
            BottomToolbar(
                onAddStep: { kind in store.send(.addStepTapped(kind)) },
                onAddRepeat: { store.send(.addRepeatGroupTapped) }
            )
        }
        .background(Color.black)
        .navigationTitle(store.templateName.isEmpty ? "Edit Workout" : store.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !store.blocks.isEmpty {
                        Button(store.isEditing ? "Done" : "Edit") {
                            store.send(.toggleEditing)
                        }
                        .foregroundStyle(Color.electricLime)
                    }
                    Button {
                        store.send(.saveTapped)
                    } label: {
                        if store.saveStatus == .saving {
                            ProgressView().tint(Color.electricLime)
                        } else {
                            Text("Save").bold()
                        }
                    }
                    .foregroundStyle(Color.electricLime)
                    .disabled(store.blocks.isEmpty || store.saveStatus == .saving)
                }
            }
        }
        .sheet(item: $store.scope(state: \.destination?.editStep, action: \.destination.editStep)) { childStore in
            EditStepSheet(store: childStore)
        }
        .sheet(item: $store.scope(state: \.destination?.editRepeatGroup, action: \.destination.editRepeatGroup)) { childStore in
            EditRepeatGroupSheet(store: childStore)
        }
    }

    private var blockList: some View {
        List {
            ForEach(store.blocks) { block in
                BlockCardView(block: block)
                    .listRowBackground(Color(hex: "#1A1B2E"))
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.blockTapped(id: block.id)) }
            }
            .onMove { source, destination in
                store.send(.moveBlocks(source, destination))
            }
            .onDelete { indexSet in
                for i in indexSet {
                    let id = store.blocks[i].id
                    store.send(.deleteBlock(id: id))
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(store.isEditing ? .active : .inactive))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Template Name Bar

private struct TemplateNameBar: View {
    @Binding var name: String
    let status: WorkoutEditor.State.SaveStatus

    var body: some View {
        HStack(spacing: 10) {
            TextField("Workout name", text: $name)
                .textFieldStyle(.plain)
                .font(.headline)
                .foregroundStyle(.white)
                .submitLabel(.done)

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#1A1B2E"))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .idle:
            EmptyView()
        case .saving:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Saving").font(.caption).foregroundStyle(.secondary)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.electricLime)
                Text("Saved").font(.caption).foregroundStyle(.secondary)
            }
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Failed").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Block Card

struct BlockCardView: View {
    let block: WorkoutBlock

    var body: some View {
        switch block {
        case .step(let step):
            StepRow(step: step)
        case .repeatGroup(let group):
            RepeatGroupRow(group: group)
        }
    }
}

private struct StepRow: View {
    let step: WorkoutStep

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color(for: step.kind))
                .frame(width: 4)

            Image(systemName: step.kind.symbolName)
                .font(.title3)
                .foregroundStyle(color(for: step.kind))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.kind.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                if let alert = step.alert {
                    Text(alert.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(step.goal.displayText)
                .font(.subheadline)
                .foregroundStyle(Color.electricLime)
        }
        .padding(.vertical, 8)
    }

    private func color(for kind: StepKind) -> Color {
        switch kind {
        case .warmup:   Color(hex: "#FF9800")
        case .work:     Color(hex: "#F44336")
        case .recovery: Color(hex: "#4CAF50")
        case .cooldown: Color(hex: "#2196F3")
        }
    }
}

private struct RepeatGroupRow: View {
    let group: RepeatGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "repeat")
                    .foregroundStyle(Color.electricLime)
                Text("Repeat \(group.iterations)×")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(group.steps.count) step\(group.steps.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(group.steps) { step in
                HStack(spacing: 8) {
                    Image(systemName: step.kind.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(step.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(step.goal.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Bottom Toolbar

private struct BottomToolbar: View {
    let onAddStep: (StepKind) -> Void
    let onAddRepeat: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(StepKind.allCases, id: \.self) { kind in
                    Button {
                        onAddStep(kind)
                    } label: {
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                }
            } label: {
                Label("Step", systemImage: "plus")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.black)
                    .background(Color.electricLime)
                    .clipShape(Capsule())
            }

            Button {
                onAddRepeat()
            } label: {
                Label("Repeat", systemImage: "repeat")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.electricLime)
                    .overlay(Capsule().stroke(Color.electricLime, lineWidth: 1.5))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(Color.black)
    }
}

// MARK: - Empty Prompt

private struct EmptyWorkshopPrompt: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.electricLime.opacity(0.6))
            Text("Build a workout")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Add warm-up, run, recovery, cool-down steps or a repeat group.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Color helpers

extension Color {
    static let electricLime = Color(hex: "#CCFF00")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview("Empty") {
    NavigationStack {
        WorkoutEditorView(
            store: .init(initialState: WorkoutEditor.State()) {
                WorkoutEditor()
            }
        )
    }
}

#Preview("With blocks") {
    let warmup = WorkoutStep(kind: .warmup, goal: .time(seconds: 600), alert: .paceZone(.easy, vdot: 40))
    let work400 = WorkoutStep(kind: .work, goal: .distance(metres: 400), alert: .paceZone(.interval, vdot: 40))
    let recovery = WorkoutStep(kind: .recovery, goal: .time(seconds: 90), alert: .paceZone(.easy, vdot: 40))
    let cooldown = WorkoutStep(kind: .cooldown, goal: .time(seconds: 600), alert: .paceZone(.easy, vdot: 40))
    let repeats = RepeatGroup(iterations: 5, steps: [work400, recovery])

    NavigationStack {
        WorkoutEditorView(
            store: .init(initialState: WorkoutEditor.State(
                blocks: [.step(warmup), .repeatGroup(repeats), .step(cooldown)]
            )) {
                WorkoutEditor()
            }
        )
    }
}
