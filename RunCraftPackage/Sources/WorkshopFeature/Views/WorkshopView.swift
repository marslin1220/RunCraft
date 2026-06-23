import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine

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
            .background(Color.brand.background)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.newWorkoutTapped)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .foregroundStyle(Color.brand.accent)
                }
            }
        } destination: { pathStore in
            switch pathStore.case {
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
        .background(Color.brand.background)
    }

    @ViewBuilder
    private var content: some View {
        switch store.selectedSegment {
        case .yours:     YoursSegment(store: store)
        case .templates: TemplatesSegment(store: store)
        case .history:   HistorySegment()
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
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(templates) { t in
                        WorkoutCardRow(
                            template: t,
                            isPreset: false,
                            onTap: { store.send(.workoutTapped(t, .yours)) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Templates segment

private struct TemplatesSegment: View {
    let store: StoreOf<Workshop>

    /// Presets grouped by training-stimulus category, in `SessionType`
    /// declaration order — only categories with at least one preset appear.
    private var groups: [(category: SessionType, presets: [WorkoutTemplate])] {
        let grouped = Dictionary(grouping: WorkoutPresets.all, by: WorkoutPresets.category(for:))
        return SessionType.allCases.compactMap { category in
            grouped[category].map { (category: category, presets: $0) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(groups, id: \.category) { group in
                    CategoryDivider(category: group.category)
                    ForEach(group.presets) { preset in
                        WorkoutCardRow(
                            template: preset,
                            isPreset: true,
                            onTap: { store.send(.workoutTapped(preset, .template)) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - Category divider

/// Section header grouping presets by `SessionType` — a coloured rail +
/// caption naming the training stimulus (e.g. "INTERVALS", "FARTLEK"), with
/// an info button explaining that stimulus's training purpose.
private struct CategoryDivider: View {
    let category: SessionType
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 3, height: 16)
                Text(category.displayName.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: category.colorHex))
                    .tracking(1.2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(category.displayName)
            .accessibilityAddTraits(.isHeader)

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo, arrowEdge: .top) {
                SessionTypeInfoPopover(category: category)
            }

            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - List row (Apple-Workout-style card)

private struct WorkoutCardRow: View {
    let template: WorkoutTemplate
    let isPreset: Bool
    let onTap: () -> Void
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    private var subtitle: String {
        template.summary(unit: paceUnit)
    }

    /// Presets are coloured by their `SessionType` category — matching the
    /// `CategoryDivider` they're grouped under. "Yours" rows keep the brand
    /// palette, since custom templates have no category.
    private var category: SessionType? {
        isPreset ? WorkoutPresets.category(for: template) : nil
    }

    var body: some View {
        WorkoutCard(
            palette: category.map(SessionPalette.palette(for:)) ?? .lime,
            symbolName: category?.symbolName ?? "figure.run",
            title: template.name,
            subtitle: subtitle,
            trailing: .chevron,
            action: onTap
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isPreset ? "Template, " : "")\(template.name), \(subtitle)")
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
                .foregroundStyle(Color.brand.accent.opacity(0.6))
            Text("No workouts yet")
                .font(.title3.bold())
                .foregroundStyle(Color.brand.textPrimary)
            Text("Start from a template or build one from scratch.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brand.textSecondary)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button(action: onBrowseTemplates) {
                    Text("Browse Templates")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.brand.accent)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                Button(action: onNew) {
                    Text("+ New workout")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.brand.accent)
                        .overlay(Capsule().stroke(Color.brand.accent, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}


// MARK: - History segment

private struct HistorySegment: View {
    @FetchAll(CompletedWorkout.order { $0.completedAt.desc() }) var runs: [CompletedWorkout]
    @FetchAll var allSessions: [PlannedSession]
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    private var sessionById: [PlannedSession.ID: PlannedSession] {
        Dictionary(uniqueKeysWithValues: allSessions.map { ($0.id, $0) })
    }

    var body: some View {
        if runs.isEmpty {
            EmptyHistoryPrompt()
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(runs) { run in
                        RunHistoryRow(
                            run: run,
                            session: run.plannedSessionId.flatMap { sessionById[$0] },
                            paceUnit: paceUnit
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct RunHistoryRow: View {
    let run: CompletedWorkout
    let session: PlannedSession?
    let paceUnit: PaceUnit

    private var sessionType: SessionType { session?.sessionType ?? .easy }

    private var title: String {
        session != nil ? sessionType.displayName : String(localized: "Run", bundle: .module)
    }

    private var distanceText: String {
        PaceFormatting.distance(metres: run.actualDistanceKm * 1_000, unit: paceUnit)
    }

    private var durationText: String {
        let total = Int(run.actualDurationSec)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private var paceText: String {
        run.avgPaceSecPerKm > 0
            ? PaceFormatting.pace(secondsPerKm: run.avgPaceSecPerKm, unit: paceUnit)
            : "--"
    }

    /// Only shown when the run is linked to a planned session.
    /// < 0.97 = ran ahead of target (cyan), > 1.05 = behind target (orange),
    /// in between = on target (green).
    private var achievementColor: Color? {
        guard session != nil, run.paceAchievementRatio > 0 else { return nil }
        switch run.paceAchievementRatio {
        case ..<0.97: return .cyan
        case 1.05...: return .orange
        default:      return .green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: sessionType.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: sessionType.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: sessionType.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brand.textPrimary)
                    Spacer()
                    Text(run.completedAt, format: .dateTime.month(.abbreviated).day().weekday(.short))
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
                HStack(spacing: 0) {
                    Text(distanceText)
                    Text("  ·  ")
                    Text(durationText)
                    Text("  ·  ")
                    Text(paceText)
                    Spacer()
                    if let color = achievementColor {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.brand.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct EmptyHistoryPrompt: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(Color.brand.accent.opacity(0.5))
            Text("No runs yet", bundle: .module)
                .font(.title3.bold())
                .foregroundStyle(Color.brand.textPrimary)
            Text(
                "Complete a workout via Apple Watch or log a run to see your history here.",
                bundle: .module
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.brand.textSecondary)
            .padding(.horizontal, 40)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    WorkshopView(store: .init(initialState: Workshop.State()) { Workshop() })
}
