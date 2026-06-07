import ComposableArchitecture
import RunCraftModels
import SQLiteData
import SwiftUI

public struct WorkshopView: View {
    @Bindable public var store: StoreOf<Workshop>

    public init(store: StoreOf<Workshop>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack(spacing: 0) {
                segmentPicker
                content
            }
            .background(Color.black)
            .navigationTitle("Workshop")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.newWorkoutTapped)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .foregroundStyle(Color.workshopLime)
                }
            }
        } destination: { pathStore in
            switch pathStore.case {
            case .detail(let detailStore):
                WorkoutDetailView(store: detailStore)
            case .editor(let editorStore):
                WorkoutEditorView(store: editorStore)
            }
        }
    }

    private var segmentPicker: some View {
        Picker("Segment", selection: $store.selectedSegment.sending(\.segmentSelected)) {
            ForEach(Workshop.Segment.allCases, id: \.self) { seg in
                Text(seg.label).tag(seg)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black)
    }

    @ViewBuilder
    private var content: some View {
        switch store.selectedSegment {
        case .yours:     YoursSegment(store: store)
        case .templates: TemplatesSegment(store: store)
        case .plan:      PlanSegment(store: store)
        }
    }
}

// MARK: - Yours segment

private struct YoursSegment: View {
    let store: StoreOf<Workshop>
    @FetchAll(WorkoutTemplate.order { $0.updatedAt.desc() }) var templates: [WorkoutTemplate]

    var body: some View {
        if templates.isEmpty {
            EmptyYoursPrompt(
                onBrowseTemplates: { store.send(.browseTemplatesTapped) },
                onNew: { store.send(.newWorkoutTapped) }
            )
        } else {
            List {
                ForEach(templates) { t in
                    WorkoutListRow(template: t, sourceIcon: nil)
                        .listRowBackground(Color(hex: "#1A1B2E"))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.workoutTapped(t, .yours))
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Templates segment

private struct TemplatesSegment: View {
    let store: StoreOf<Workshop>

    var body: some View {
        List {
            ForEach(WorkoutPresets.all) { preset in
                WorkoutListRow(template: preset, sourceIcon: "sparkles")
                    .listRowBackground(Color(hex: "#1A1B2E"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.send(.workoutTapped(preset, .template))
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Plan segment

private struct PlanSegment: View {
    let store: StoreOf<Workshop>
    @FetchOne(RaceGoal.order { $0.createdAt.desc() }) var goal: RaceGoal?
    @FetchAll var allWeeks: [TrainingWeek]
    @FetchAll(PlannedSession.none) var thisWeekSessions: [PlannedSession] = []

    private var currentWeek: TrainingWeek? {
        TrainingWeek.current(in: allWeeks)
    }

    var body: some View {
        Group {
            if goal == nil {
                EmptyPlanPrompt()
            } else if currentWeek == nil {
                ProgressView().tint(Color.workshopLime)
            } else {
                List {
                    ForEach(orderedDays(), id: \.dayOfWeek) { row in
                        if let session = row.session {
                            PlanSessionRow(
                                dayOfWeek: row.dayOfWeek,
                                session: session,
                                vdot: goal?.currentVDOT ?? 40
                            ) { template in
                                store.send(.workoutTapped(template, .planSession))
                            }
                            .listRowBackground(Color(hex: "#1A1B2E"))
                        } else {
                            PlanRestRow(dayOfWeek: row.dayOfWeek)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task(id: currentWeek?.id) { await loadThisWeekSessions() }
    }

    private func orderedDays() -> [(dayOfWeek: Int, session: PlannedSession?)] {
        (1...7).map { day in
            let s = thisWeekSessions.first { $0.dayOfWeek == day }
            return (day, s)
        }
    }

    private func loadThisWeekSessions() async {
        guard let weekId = currentWeek?.id else { return }
        do {
            try await $thisWeekSessions.load(
                PlannedSession.where { $0.weekId.eq(weekId) }.order(by: \.dayOfWeek)
            )
        } catch {
            print("load planned sessions failed: \(error)")
        }
    }
}

private struct PlanSessionRow: View {
    let dayOfWeek: Int
    let session: PlannedSession
    let vdot: Double
    let onTap: (WorkoutTemplate) -> Void

    var body: some View {
        Button {
            let template = PlanSessionAdapter.makeTemplate(from: session, vdot: vdot)
            onTap(template)
        } label: {
            HStack(spacing: 12) {
                Text(dayLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(hex: session.sessionType.colorHex))
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.sessionType.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    if !session.notes.isEmpty {
                        Text(session.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                if let km = session.targetDistanceKm {
                    Text("\(km, format: .number.precision(.fractionLength(0...1))) km")
                        .font(.subheadline)
                        .foregroundStyle(Color.workshopLime)
                }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var dayLabel: String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = dayOfWeek - 1
        return (idx >= 0 && idx < days.count) ? days[idx] : "?"
    }
}

private struct PlanRestRow: View {
    let dayOfWeek: Int
    var body: some View {
        HStack {
            Text(dayLabel)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 36)
            Text("Rest day")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }
    private var dayLabel: String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = dayOfWeek - 1
        return (idx >= 0 && idx < days.count) ? days[idx] : "?"
    }
}

// MARK: - List row

private struct WorkoutListRow: View {
    let template: WorkoutTemplate
    let sourceIcon: String?

    private var totalSteps: Int {
        template.blocks.reduce(0) { acc, block in
            switch block {
            case .step: acc + 1
            case .repeatGroup(let g): acc + g.steps.count * g.iterations
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(sourceIcon != nil ? Color.workshopLime.opacity(0.2) : Color.white.opacity(0.08))
                .overlay(
                    Image(systemName: sourceIcon ?? "figure.run")
                        .foregroundStyle(sourceIcon != nil ? Color.workshopLime : .white)
                )
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.subheadline.bold()).foregroundStyle(.white)
                Text("\(template.blocks.count) blocks · \(totalSteps) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty states

private struct EmptyYoursPrompt: View {
    let onBrowseTemplates: () -> Void
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.workshopLime.opacity(0.6))
            Text("No workouts yet")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Start from a template or build one from scratch.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button(action: onBrowseTemplates) {
                    Text("Browse Templates")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.workshopLime)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                Button(action: onNew) {
                    Text("+ New workout")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.workshopLime)
                        .overlay(Capsule().stroke(Color.workshopLime, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct EmptyPlanPrompt: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No active plan")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Create a race goal in the Plan tab to see daily training here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helpers

extension Color {
    fileprivate static let workshopLime = Color(red: 0.8, green: 1.0, blue: 0.0)
}

#Preview {
    WorkshopView(store: .init(initialState: Workshop.State()) { Workshop() })
}
