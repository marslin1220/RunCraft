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
            .background(
                LinearGradient(
                    colors: [Color.brand.accent.opacity(0.07), Color.brand.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(Text("Workouts", bundle: .module))
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
            Text("No workouts yet", bundle: .module)
                .font(.title3.bold())
                .foregroundStyle(Color.brand.textPrimary)
            Text("Start from a template or build one from scratch.", bundle: .module)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brand.textSecondary)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button(action: onBrowseTemplates) {
                    Text("Browse Templates", bundle: .module)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.brand.accent)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                Button(action: onNew) {
                    Text("+ New workout", bundle: .module)
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
    @State private var selectedRun: CompletedWorkout?

    private var sessionById: [PlannedSession.ID: PlannedSession] {
        Dictionary(uniqueKeysWithValues: allSessions.map { ($0.id, $0) })
    }

    /// Runs grouped by calendar month, newest month first.
    private var groupedByMonth: [(monthStart: Date, runs: [CompletedWorkout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { run -> Date in
            calendar.dateInterval(of: .month, for: run.completedAt)?.start ?? run.completedAt
        }
        return grouped
            .map { (monthStart: $0.key, runs: $0.value.sorted { $0.completedAt > $1.completedAt }) }
            .sorted { $0.monthStart > $1.monthStart }
    }

    var body: some View {
        if runs.isEmpty {
            EmptyHistoryPrompt()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groupedByMonth, id: \.monthStart) { group in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(group.runs) { run in
                                    let session = run.plannedSessionId.flatMap { sessionById[$0] }
                                    Button {
                                        selectedRun = run
                                    } label: {
                                        RunHistoryRow(
                                            run: run,
                                            session: session,
                                            paceUnit: paceUnit
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if run.id != group.runs.last?.id {
                                        Divider()
                                            .padding(.leading, 74)
                                            .opacity(0.2)
                                    }
                                }
                            }
                            .glassCard(cornerRadius: 16)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } header: {
                            MonthHeader(monthStart: group.monthStart, runs: group.runs)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .sheet(item: $selectedRun) { run in
                RunDetailView(
                    run: run,
                    session: run.plannedSessionId.flatMap { sessionById[$0] },
                    paceUnit: paceUnit
                )
            }
        }
    }
}

// MARK: - Month section header

private struct MonthHeader: View {
    let monthStart: Date
    let runs: [CompletedWorkout]

    private var totalKm: Double { runs.reduce(0) { $0 + $1.actualDistanceKm } }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(monthStart, format: .dateTime.year().month(.wide))
                .font(.headline)
                .foregroundStyle(Color.brand.textPrimary)
            Spacer()
            Text(String(format: "%d 次 · %.1f km", runs.count, totalKm))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.brand.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.brand.background)
    }
}

// MARK: - Run row (Apple Fitness–inspired)

private struct RunHistoryRow: View {
    let run: CompletedWorkout
    let session: PlannedSession?
    let paceUnit: PaceUnit

    private var sessionType: SessionType { session?.sessionType ?? .easy }
    private var accentColor: Color { Color(hex: sessionType.colorHex) }

    private var title: String {
        sessionType.displayName
    }

    private var distanceKm: Double { run.actualDistanceKm }
    private var distanceValue: String {
        String(format: "%.2f", paceUnit == .perKilometre ? distanceKm : distanceKm * 0.621371)
    }
    private var distanceUnit: String { paceUnit == .perKilometre ? "km" : "mi" }

    private var durationText: String {
        let total = Int(run.actualDurationSec)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private var paceText: String {
        run.avgPaceSecPerKm > 0
            ? PaceFormatting.paceMinutesSeconds(secondsPerKm: run.avgPaceSecPerKm, unit: paceUnit)
            : "--"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: sessionType.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brand.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(run.completedAt, format: .dateTime.weekday(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(distanceValue)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.brand.textPrimary)
                    Text(distanceUnit)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.brand.textSecondary)
                    Spacer()
                    Text(durationText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.brand.textSecondary)
                }

                Text(paceText + " / " + distanceUnit)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.brand.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Run detail sheet

private struct RunDetailView: View {
    let run: CompletedWorkout
    let session: PlannedSession?
    let paceUnit: PaceUnit
    @Environment(\.dismiss) private var dismiss

    private var sessionType: SessionType { session?.sessionType ?? .easy }
    private var accentColor: Color { Color(hex: sessionType.colorHex) }
    private var title: String { sessionType.displayName }

    private var distanceKm: Double { run.actualDistanceKm }
    private var distanceValue: String {
        String(format: "%.2f", paceUnit == .perKilometre ? distanceKm : distanceKm * 0.621371)
    }
    private var distanceUnit: String { paceUnit == .perKilometre ? "km" : "mi" }

    private var durationText: String {
        let total = Int(run.actualDurationSec)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private var paceText: String {
        run.avgPaceSecPerKm > 0
            ? PaceFormatting.paceMinutesSeconds(secondsPerKm: run.avgPaceSecPerKm, unit: paceUnit)
            : "--"
    }

    private var achievementLabel: String {
        guard run.plannedSessionId != nil, run.paceAchievementRatio > 0 else {
            return String(localized: "—", bundle: .module)
        }
        switch run.paceAchievementRatio {
        case ..<0.97: return String(localized: "Ahead", bundle: .module)
        case 1.05...: return String(localized: "Behind", bundle: .module)
        default:      return String(localized: "On pace", bundle: .module)
        }
    }

    private var achievementColor: Color {
        guard run.plannedSessionId != nil, run.paceAchievementRatio > 0 else { return Color.brand.textSecondary }
        switch run.paceAchievementRatio {
        case ..<0.97: return .cyan
        case 1.05...: return .orange
        default:      return Color.brand.success
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Type + date header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(accentColor.opacity(0.15)).frame(width: 52, height: 52)
                            Image(systemName: sessionType.symbolName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.brand.textPrimary)
                            Text(run.completedAt, format: .dateTime.year().month(.abbreviated).day().weekday(.short).hour().minute())
                                .font(.subheadline)
                                .foregroundStyle(Color.brand.textSecondary)
                        }
                        Spacer()
                    }

                    // 2×2 metric grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(
                            label: String(localized: "Distance", bundle: .module),
                            value: distanceValue,
                            unit: distanceUnit,
                            color: accentColor
                        )
                        MetricTile(
                            label: String(localized: "Duration", bundle: .module),
                            value: durationText,
                            unit: nil,
                            color: nil
                        )
                        MetricTile(
                            label: String(localized: "Avg Pace", bundle: .module),
                            value: paceText,
                            unit: "/ " + distanceUnit,
                            color: accentColor
                        )
                        MetricTile(
                            label: String(localized: "Pace Score", bundle: .module),
                            value: achievementLabel,
                            unit: nil,
                            color: run.paceAchievementRatio > 0 && run.plannedSessionId != nil ? achievementColor : nil
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle(run.completedAt.formatted(.dateTime.month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.brand.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done", bundle: .module) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Metric tile (used in RunDetailView)

private struct MetricTile: View {
    let label: String
    let value: String
    let unit: String?
    let color: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.brand.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(color ?? Color.brand.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
            .minimumScaleFactor(0.7)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 14)
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
