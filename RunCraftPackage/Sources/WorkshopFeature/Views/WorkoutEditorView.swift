import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SwiftUI
import VDOTEngine

public struct WorkoutEditorView: View {
    @Bindable public var store: StoreOf<WorkoutEditor>

    public init(store: StoreOf<WorkoutEditor>) {
        self.store = store
    }

    public var body: some View {
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
        .background(Color.brand.background)
        // Floating CTA above the home-indicator. safeAreaInset reserves
        // the right amount of room automatically — no manual spacer rows
        // in the list, and the system handles inset on the home gesture
        // bar (HIG `fixed-element-offset`).
        .safeAreaInset(edge: .bottom) {
            Group {
                if store.canStartOnWatch {
                    sendToWatchButton
                } else {
                    previewOnlyNotice
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [Color.brand.background.opacity(0), Color.brand.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .offset(y: 20)
                .allowsHitTesting(false)
            )
        }
        .task { store.send(.onTask) }
        .navigationTitle(store.templateName.isEmpty ? "Edit Workout" : store.templateName)
        .navigationBarTitleDisplayMode(.inline)
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

                    if store.source == .planSession,
                       let session = store.planSession,
                       !session.sessionType.alternatives.isEmpty {
                        Menu {
                            ForEach(session.sessionType.alternatives) { alt in
                                Button {
                                    store.send(.swapSession(alt.sessionType, variantNote: alt.variantNote))
                                } label: {
                                    Label(alt.title, systemImage: alt.sessionType.symbolName)
                                }
                            }
                        } label: {
                            Label("Change Session Type", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Divider()
                    }

                    Button {
                        store.send(.duplicateTapped)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.brand.accent)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.saveTapped)
                } label: {
                    if store.saveStatus == .saving {
                        ProgressView().tint(Color.brand.accent)
                    } else {
                        Text("Save").bold()
                    }
                }
                .foregroundStyle(Color.brand.accent)
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.brand.textSecondary.opacity(0.10), lineWidth: 0.5)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
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
            .background(Color.brand.accent)
            .clipShape(Capsule())
            // Subtle elevation — communicates "floating CTA", not glow
            // effect. HIG `elevation-consistent`: shadow signals depth.
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(store.syncStatus == .sending || store.syncStatus == .sent || store.blocks.isEmpty)
        .opacity(store.blocks.isEmpty ? 0.4 : 1)
    }

    /// Shown instead of "Start Workout" for a plan session that isn't
    /// today's — completing it now would get logged against today's
    /// actual session via HealthKit sync-back, not this one.
    private var previewOnlyNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
            Text("Preview only — start this from the Plan tab on its scheduled day.")
        }
        .font(.footnote)
        .foregroundStyle(Color.brand.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder private var sendIcon: some View {
        switch store.syncStatus {
        case .sending: ProgressView().tint(.black)
        case .sent:    Image(systemName: "checkmark.circle.fill")
        default:       Image(systemName: "play.fill")
        }
    }

    private var sendLabel: Text {
        switch store.syncStatus {
        case .sending: Text("Starting…")
        case .sent:    Text("Starting on your Apple Watch…")
        default:       Text("Start Workout")
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
                    .foregroundStyle(Color.brand.textPrimary)
                    .submitLabel(.done)

                Spacer()

                statusBadge
            }
            sourceTag
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.brand.surface)
    }

    @ViewBuilder
    private var sourceTag: some View {
        HStack(spacing: 4) {
            Image(systemName: sourceIcon)
            Text(sourceLabel)
        }
        .font(.caption)
        .foregroundStyle(Color.brand.textSecondary)
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
                Text("Saving").font(.caption).foregroundStyle(Color.brand.textSecondary)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brand.accent)
                Text("Saved").font(.caption).foregroundStyle(Color.brand.textSecondary)
            }
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Failed").font(.caption).foregroundStyle(Color.brand.textSecondary)
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
                    .foregroundStyle(Color.brand.textPrimary)
                if let alert = step.alert {
                    Text(alert.displayText)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }

            Spacer()

            Text(step.goal.displayText)
                .font(.subheadline)
                .foregroundStyle(Color.brand.accent)
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
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    /// Total metres covered by work steps across all iterations.
    /// nil when any work step has a non-distance goal.
    private var totalWorkMetres: Double? {
        let workSteps = group.steps.filter { $0.kind == .work }
        guard !workSteps.isEmpty else { return nil }
        var total = 0.0
        for step in workSteps {
            guard case .distance(let m) = step.goal else { return nil }
            total += m
        }
        return total * Double(group.iterations)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "repeat")
                    .font(.caption.bold())
                    .foregroundStyle(Color.brand.accent)
                Text("Repeat \(group.iterations)×")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brand.textPrimary)
                Spacer()
                if let total = totalWorkMetres {
                    Text(StepGoal.distance(metres: total).displayText + " work")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.brand.textSecondary)
                } else {
                    Text("\(group.steps.count) step\(group.steps.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }

            VStack(spacing: 6) {
                ForEach(group.steps) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: step.kind.symbolName)
                            .font(.caption)
                            .foregroundStyle(stepColor(step.kind))
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.kind.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.brand.textPrimary)
                            if let alert = step.alert {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 8, weight: .semibold))
                                    Text(alert.displayText(unit: paceUnit))
                                        .font(.caption2.monospacedDigit())
                                }
                                .foregroundStyle(stepColor(step.kind).opacity(0.8))
                            }
                        }

                        Spacer()

                        Text(step.goal.displayText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.brand.accent)
                    }
                    .padding(.leading, 24)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Color.brand.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
    }

    private func stepColor(_ kind: StepKind) -> Color {
        switch kind {
        case .warmup:   Color(hex: "#FF9800")
        case .work:     Color(hex: "#F44336")
        case .recovery: Color(hex: "#4CAF50")
        case .cooldown: Color(hex: "#2196F3")
        }
    }
}

// MARK: - Empty Prompt

private struct EmptyWorkshopPrompt: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brand.accent.opacity(0.6))
            Text("Build a workout")
                .font(.title3.bold())
                .foregroundStyle(Color.brand.textPrimary)
            Text("Tap ⋯ to add a Step or a Repeat group.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brand.textSecondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Repeat — with pace targets") {
    let group = RepeatGroup(
        iterations: 8,
        steps: [
            WorkoutStep(kind: .work,     goal: .distance(metres: 200), alert: .paceRange(minSecPerKm: 270, maxSecPerKm: 300)),
            WorkoutStep(kind: .recovery, goal: .distance(metres: 200), alert: .paceRange(minSecPerKm: 450, maxSecPerKm: 480)),
        ]
    )
    return BlockCardView(block: .repeatGroup(group))
        .padding()
        .background(Color.brand.background)
}

#Preview("Repeat — with HR targets") {
    let group = RepeatGroup(
        iterations: 4,
        steps: [
            WorkoutStep(kind: .work,     goal: .time(seconds: 180), alert: .heartRate(min: 155, max: 170)),
            WorkoutStep(kind: .recovery, goal: .time(seconds: 90)),
        ]
    )
    return BlockCardView(block: .repeatGroup(group))
        .padding()
        .background(Color.brand.background)
}

#Preview("Repeat — time-based, no pace alert") {
    let group = RepeatGroup(
        iterations: 6,
        steps: [
            WorkoutStep(kind: .work,     goal: .time(seconds: 60)),
            WorkoutStep(kind: .recovery, goal: .time(seconds: 60)),
        ]
    )
    return BlockCardView(block: .repeatGroup(group))
        .padding()
        .background(Color.brand.background)
}

#Preview("Full workout — Repetition session") {
    let blocks: [WorkoutBlock] = [
        .step(WorkoutStep(kind: .warmup, goal: .distance(metres: 1500),
                          alert: .paceRange(minSecPerKm: 384, maxSecPerKm: 450))),
        .repeatGroup(RepeatGroup(
            iterations: 8,
            steps: [
                WorkoutStep(kind: .work,     goal: .distance(metres: 200), alert: .paceRange(minSecPerKm: 270, maxSecPerKm: 300)),
                WorkoutStep(kind: .recovery, goal: .distance(metres: 200)),
            ]
        )),
        .step(WorkoutStep(kind: .cooldown, goal: .distance(metres: 1500),
                          alert: .paceRange(minSecPerKm: 384, maxSecPerKm: 450))),
    ]
    return ScrollView {
        VStack(spacing: 0) {
            ForEach(blocks) { block in
                BlockCardView(block: block)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                Divider().padding(.leading, 16)
            }
        }
    }
    .background(Color.brand.background)
}

// MARK: - Color helpers

extension Color {
    /// Legacy alias for the brand accent. New code should use
    /// `Color.brand.accent` directly.
    static let electricLime = Color.brand.accent
}
