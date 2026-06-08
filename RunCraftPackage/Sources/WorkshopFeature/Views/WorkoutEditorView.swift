import ComposableArchitecture
import RunCraftModels
import SwiftUI

public struct WorkoutEditorView: View {
    @Bindable public var store: StoreOf<WorkoutEditor>

    public init(store: StoreOf<WorkoutEditor>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TemplateNameBar(
                    name: $store.templateName,
                    status: store.saveStatus,
                    source: store.source
                )
                if store.blocks.isEmpty {
                    EmptyWorkshopPrompt()
                } else {
                    blockList
                }
            }

            sendToWatchButton
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .background(Color.black)
        .navigationTitle(store.templateName.isEmpty ? "Edit Workout" : store.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu {
                        ForEach(StepKind.allCases, id: \.self) { kind in
                            Button {
                                store.send(.addStepTapped(kind))
                            } label: {
                                Label(kind.displayName, systemImage: kind.symbolName)
                            }
                        }
                    } label: {
                        Label("Add Step", systemImage: "plus")
                    }

                    Button {
                        store.send(.addRepeatGroupTapped)
                    } label: {
                        Label("Add Repeat", systemImage: "repeat")
                    }

                    Divider()

                    Button {
                        store.send(.duplicateTapped)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.electricLime)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
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
        .sheet(item: $store.scope(state: \.destination?.editStep, action: \.destination.editStep)) { childStore in
            EditStepSheet(store: childStore)
        }
        .sheet(item: $store.scope(state: \.destination?.editRepeatGroup, action: \.destination.editRepeatGroup)) { childStore in
            EditRepeatGroupSheet(store: childStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var blockList: some View {
        List {
            ForEach(store.blocks) { block in
                BlockCardView(block: block)
                    .listRowBackground(Color(hex: "#1A1B2E"))
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.blockTapped(id: block.id)) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.send(.deleteBlock(id: block.id))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onMove { source, destination in
                store.send(.moveBlocks(source, destination))
            }

            // Bottom spacer so the Send-to-Watch button doesn't cover the
            // last block when the list grows long.
            Color.clear
                .frame(height: 100)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Send to Watch

    @ViewBuilder
    private var sendToWatchButton: some View {
        Button {
            store.send(.startTapped)
        } label: {
            HStack(spacing: 8) {
                sendIcon
                sendLabel
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.electricLime)
            .clipShape(Capsule())
            .shadow(color: Color.electricLime.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(store.syncStatus == .sending || store.blocks.isEmpty)
        .opacity(store.blocks.isEmpty ? 0.4 : 1)
    }

    @ViewBuilder private var sendIcon: some View {
        switch store.syncStatus {
        case .sending: ProgressView().tint(.black)
        case .sent:    Image(systemName: "checkmark.circle.fill")
        default:       Image(systemName: "applewatch.radiowaves.left.and.right")
        }
    }

    private var sendLabel: Text {
        switch store.syncStatus {
        case .sending: Text("Sending to Apple Watch…")
        case .sent:    Text("Sent · Open Watch")
        default:       Text("Send to Apple Watch")
        }
    }
}

// MARK: - Template Name Bar

private struct TemplateNameBar: View {
    @Binding var name: String
    let status: WorkoutEditor.State.SaveStatus
    let source: WorkoutEditor.State.Source

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TextField("Workout name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .submitLabel(.done)

                Spacer()

                statusBadge
            }
            sourceTag
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#1A1B2E"))
    }

    @ViewBuilder
    private var sourceTag: some View {
        HStack(spacing: 4) {
            Image(systemName: sourceIcon)
            Text(sourceLabel)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var sourceIcon: String {
        switch source {
        case .yours:       "person.fill"
        case .template:    "sparkles"
        case .planSession: "calendar"
        }
    }

    private var sourceLabel: String {
        switch source {
        case .yours:       "Your workout"
        case .template:    "From template — Save creates a copy"
        case .planSession: "From your plan — Save creates a copy"
        }
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
            Text("Tap ⋯ to add a Step or a Repeat group.")
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
