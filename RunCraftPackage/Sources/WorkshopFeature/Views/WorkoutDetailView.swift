import ComposableArchitecture
import RunCraftModels
import SwiftUI

public struct WorkoutDetailView: View {
    @Bindable public var store: StoreOf<WorkoutDetail>

    public init(store: StoreOf<WorkoutDetail>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    blocksSection
                    Spacer(minLength: 120) // room for floating button
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }

            startButton
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .background(Color.black)
        .navigationTitle(store.workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            if store.source != .yours {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.duplicateTapped)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .foregroundStyle(Color.detailLime)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { store.send(.editTapped) }
                    .foregroundStyle(Color.detailLime)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: sourceIcon)
                    .foregroundStyle(Color.detailLime)
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(estimatedSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var sourceIcon: String {
        switch store.source {
        case .yours:       "person.fill"
        case .template:    "sparkles"
        case .planSession: "calendar"
        }
    }

    private var sourceLabel: String {
        switch store.source {
        case .yours:       "Your workout"
        case .template:    "Template"
        case .planSession: "From your plan"
        }
    }

    private var estimatedSummary: String {
        let totalSteps = store.workout.blocks.reduce(0) { acc, block in
            switch block {
            case .step: acc + 1
            case .repeatGroup(let g): acc + g.steps.count * g.iterations
            }
        }
        let totalMetres = store.workout.blocks.reduce(0.0) { acc, block in
            switch block {
            case .step(let s):
                if case .distance(let m) = s.goal { return acc + m }
                return acc
            case .repeatGroup(let g):
                let per = g.steps.reduce(0.0) { sub, s in
                    if case .distance(let m) = s.goal { return sub + m }
                    return sub
                }
                return acc + per * Double(g.iterations)
            }
        }
        let km = totalMetres / 1_000
        return "\(totalSteps) steps · ≈ \(km.formatted(.number.precision(.fractionLength(0...1)))) km"
    }

    // MARK: - Blocks

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.workout.blocks) { block in
                Button {
                    store.send(.blockTapped(id: block.id))
                } label: {
                    BlockSummaryCard(block: block)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Start button

    private var startButton: some View {
        Button {
            store.send(.startTapped)
        } label: {
            HStack(spacing: 8) {
                startIcon
                startLabel
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.detailLime)
            .clipShape(Capsule())
            .shadow(color: Color.detailLime.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(store.syncStatus == .sending)
    }

    @ViewBuilder private var startIcon: some View {
        switch store.syncStatus {
        case .sending:
            ProgressView().tint(.black)
        case .sent:
            Image(systemName: "checkmark.circle.fill")
        default:
            Image(systemName: "applewatch.radiowaves.left.and.right")
        }
    }

    private var startLabel: Text {
        switch store.syncStatus {
        case .sending: Text("Sending to Apple Watch…")
        case .sent:    Text("Sent · Open Watch")
        default:       Text("Send to Apple Watch")
        }
    }
}

// MARK: - Block summary card (read-only)

private struct BlockSummaryCard: View {
    let block: WorkoutBlock

    var body: some View {
        switch block {
        case .step(let s):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorFor(s.kind))
                    .frame(width: 4, height: 36)
                Image(systemName: s.kind.symbolName)
                    .foregroundStyle(colorFor(s.kind))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.kind.displayName).font(.subheadline.bold()).foregroundStyle(.white)
                    if let alert = s.alert {
                        Text(alert.displayText).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(s.goal.displayText).font(.subheadline).foregroundStyle(Color.detailLime)
            }
            .padding(12)
            .background(Color(hex: "#1A1B2E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .repeatGroup(let g):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundStyle(Color.detailLime)
                    Text("Repeat \(g.iterations)×")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                }
                ForEach(g.steps) { s in
                    HStack(spacing: 8) {
                        Image(systemName: s.kind.symbolName)
                            .foregroundStyle(.secondary).frame(width: 16)
                        Text(s.kind.displayName).font(.caption).foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text(s.goal.displayText).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 20)
                }
            }
            .padding(12)
            .background(Color(hex: "#1A1B2E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func colorFor(_ kind: StepKind) -> Color {
        switch kind {
        case .warmup:   Color(hex: "#FF9800")
        case .work:     Color(hex: "#F44336")
        case .recovery: Color(hex: "#4CAF50")
        case .cooldown: Color(hex: "#2196F3")
        }
    }
}

// MARK: - Color helpers for detail file (avoid Color extension name clash)

extension Color {
    fileprivate static let detailLime = Color(red: 0.8, green: 1.0, blue: 0.0)
}
