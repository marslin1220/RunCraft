import ComposableArchitecture
import DesignSystem
import IssueReporting
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine
import WorkshopFeature

public struct PlanView: View {
    @Bindable public var store: StoreOf<TrainingPlan>
    @FetchOne public var activeGoal: RaceGoal?
    @FetchAll public var allWeeks: [TrainingWeek]

    public init(store: StoreOf<TrainingPlan>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                VStack(spacing: 24) {
                    if let goal = activeGoal {
                        Button {
                            store.send(.countdownTapped)
                        } label: {
                            RaceCountdownRing(goal: goal)
                                .padding(.top, 16)
                        }
                        .buttonStyle(.plain)

                        if let upgrade = store.vdotUpgrade {
                            VDOTUpgradeBanner(upgrade: upgrade,
                                onAccept: { store.send(.acceptVDOTUpgradeTapped) },
                                onDismiss: { store.send(.dismissVDOTUpgrade) })
                        }

                        if case let .suggestDowngrade(reason) = store.recoveryAdvice {
                            RecoveryAdviceBanner(reason: reason,
                                onApply: { store.send(.applyDowngradeTapped) },
                                onDismiss: { store.send(.dismissRecoveryAdvice) })
                        }

                        if let zones = store.paceZones {
                            PaceZonesSummaryCard(zones: zones) { zone in
                                store.send(.paceChipTapped(zone))
                            }
                        }

                        if let currentWeek = currentWeek {
                            WeekSessionsSection(
                                week: currentWeek,
                                vdot: store.currentVDOT
                            ) { session in
                                store.send(.sessionTapped(session))
                            }
                        }
                    } else {
                        EmptyPlanPrompt {
                            store.send(.createGoalButtonTapped)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.black)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                if store.hasGoal {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                store.send(.recalculateVDOTRequested)
                            } label: {
                                Label("Edit goal / recalculate", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                store.send(.deletePlanRequested)
                            } label: {
                                Label("Delete plan", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.brand.accent)
                        }
                    }
                }
            }
            .onAppear { store.send(.onAppear) }
            .sheet(item: $store.scope(state: \.destination?.setupRaceGoal, action: \.destination.setupRaceGoal)) { setupStore in
                SetupRaceGoalView(store: setupStore)
            }
            .alert($store.scope(state: \.destination?.deleteConfirm, action: \.destination.deleteConfirm))
        } destination: { pathStore in
            switch pathStore.case {
            case .weekSchedule(let scheduleStore):
                WeekScheduleView(
                    store: scheduleStore,
                    allWeeks: allWeeks,
                    currentVDOT: store.currentVDOT
                )
            case .editor(let editorStore):
                WorkoutEditorView(store: editorStore)
            }
        }
    }

    private var currentWeek: TrainingWeek? {
        TrainingWeek.current(in: allWeeks)
    }
}

// MARK: - Subviews

private struct RaceCountdownRing: View {
    let goal: RaceGoal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Best-effort phase + week-number context based on days until race.
    /// 16-week plan, ordered: Base (weeks 1–4) → Build (5–8) → Peak (9–12)
    /// → Taper (13–16). Returns nil once the race window is past.
    private var phaseContext: (week: Int, phase: TrainingPhase)? {
        let days = goal.daysUntilRace
        guard days >= 0 else { return nil }
        let totalDays = 16 * 7
        let elapsedDays = max(0, totalDays - days)
        let weekIndex = min(15, elapsedDays / 7) // 0…15
        let phase: TrainingPhase = switch weekIndex {
        case 0..<4:  .base
        case 4..<8:  .build
        case 8..<12: .peak
        default:     .taper
        }
        return (week: weekIndex + 1, phase: phase)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        Color.brand.accent,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: ringProgress)

                VStack(spacing: 2) {
                    Text("\(max(goal.daysUntilRace, 0))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("days")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(ringAccessibilityLabel)

            Text(goal.name)
                .font(.headline)
                .foregroundStyle(.white)

            if let ctx = phaseContext {
                Text("Week \(ctx.week) of 16 · \(ctx.phase.displayName)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.brand.accent)
            }

            Text(goal.targetDate, format: .dateTime.day().month().year())
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
        }
    }

    private var ringProgress: Double {
        let total = 16.0 * 7.0
        let remaining = Double(max(goal.daysUntilRace, 0))
        return max(0, min(1, 1 - remaining / total))
    }

    private var ringAccessibilityLabel: String {
        var parts: [String] = ["\(max(goal.daysUntilRace, 0)) days until \(goal.name)"]
        if let ctx = phaseContext {
            parts.append("Currently week \(ctx.week) of 16, \(ctx.phase.displayName) phase")
        }
        return parts.joined(separator: ". ")
    }
}

private struct PaceZonesSummaryCard: View {
    let zones: PaceZones
    let onTap: (PaceZoneName) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Training Paces")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Text("tap to build")
                    .font(.caption2)
                    .foregroundStyle(Color.brand.textSecondary)
            }

            HStack(spacing: 8) {
                ForEach(PaceZoneName.allCases, id: \.self) { zone in
                    tappableChip(zone)
                }
            }
        }
        .padding()
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tappableChip(_ zone: PaceZoneName) -> some View {
        Button {
            onTap(zone)
        } label: {
            PaceChip(label: zone.letter, pace: zones[zone].formatted(), color: Self.color(for: zone))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(zone.fullName) pace, \(zones[zone].formatted())")
        .accessibilityHint("Builds a workout in the \(zone.fullName) zone")
    }

    private static func color(for zone: PaceZoneName) -> Color {
        switch zone {
        case .easy:       Color.brand.zone.easy
        case .marathon:   Color.brand.zone.marathon
        case .threshold:  Color.brand.zone.threshold
        case .interval:   Color.brand.zone.interval
        case .repetition: Color.brand.zone.repetition
        }
    }
}

private struct PaceChip: View {
    let label: String
    let pace: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(pace.components(separatedBy: " ").first ?? pace)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }
}

private extension PaceZoneName {
    /// Full word used in VoiceOver labels.
    var fullName: String {
        switch self {
        case .easy:       "Easy"
        case .marathon:   "Marathon"
        case .threshold:  "Threshold"
        case .interval:   "Interval"
        case .repetition: "Repetition"
        }
    }
}

private struct WeekSessionsSection: View {
    let week: TrainingWeek
    let vdot: Double
    let onSessionTap: (PlannedSession) -> Void
    @FetchAll(PlannedSession.none) var sessions: [PlannedSession]
    @FetchAll var completedThisWeek: [CompletedWorkout]

    private var completedSessionIds: Set<UUID> {
        Set(completedThisWeek.compactMap(\.plannedSessionId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Week \(week.weekNumber) · \(week.phase.displayName)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(week.targetWeeklyKm, format: .number.precision(.fractionLength(0))) km")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.accent)
            }

            ForEach(sessions) { session in
                Button {
                    onSessionTap(session)
                } label: {
                    SessionCard(
                        session: session,
                        weekStart: week.startDate,
                        vdot: vdot,
                        isCompleted: completedSessionIds.contains(session.id)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: week.id) { await loadWeekData() }
    }

    private func loadWeekData() async {
        _ = await withErrorReporting {
            try await $sessions.load(
                PlannedSession
                    .where { $0.weekId.eq(week.id) }
                    .order(by: \.dayOfWeek)
            )
        }
    }
}

private struct SessionCard: View {
    let session: PlannedSession
    let weekStart: Date
    let vdot: Double
    let isCompleted: Bool

    /// Live pace string for the work portion, computed from the session's
    /// stored zone and the current VDOT. Returns nil for rest days or when
    /// the VDOT isn't known yet.
    private var livePaceText: String? {
        guard let zone = session.targetPaceZone, vdot > 0 else { return nil }
        return VDOTCalculator.paceRange(for: zone, vdot: vdot).formatted()
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: session.sessionType.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(dayLabel)
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)

                Text(session.sessionType.displayName)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)

                if let pace = livePaceText {
                    Text(pace)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.brand.textSecondary)
                        .lineLimit(1)
                } else if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let km = session.targetDistanceKm {
                Text("\(km, format: .number.precision(.fractionLength(0))) km")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.brand.textSecondary)
            } else if let min = session.targetDurationMin {
                Text("\(min) min")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.brand.textSecondary)
            }

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brand.success)
            }
        }
        .padding(12)
        .background(Color.brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isCompleted ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isCompleted ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [dayLabel, session.sessionType.displayName]
        if let pace = livePaceText { parts.append("pace \(pace)") }
        if let km = session.targetDistanceKm {
            parts.append("\(Int(km)) kilometres")
        } else if let min = session.targetDurationMin {
            parts.append("\(min) minutes")
        }
        if isCompleted { parts.append("completed") }
        return parts.joined(separator: ", ")
    }

    private var dayLabel: String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = session.dayOfWeek - 1
        guard idx >= 0, idx < days.count else { return "" }
        return days[idx]
    }
}

private struct VDOTUpgradeBanner: View {
    let upgrade: TrainingPlan.VDOTUpgrade
    let onAccept: () -> Void
    let onDismiss: () -> Void

    private var oldVDOT: String { upgrade.oldVDOT.formatted(.number.precision(.fractionLength(1))) }
    private var newVDOT: String { upgrade.newVDOT.formatted(.number.precision(.fractionLength(1))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brand.accent)
                    .accessibilityHidden(true)
                Text("VDOT improved")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brand.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss VDOT upgrade")
            }

            HStack(spacing: 6) {
                Text(oldVDOT)
                    .foregroundStyle(Color.brand.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.brand.textSecondary)
                    .accessibilityHidden(true)
                Text(newVDOT)
                    .bold()
                    .foregroundStyle(Color.brand.accent)
            }
            .font(.title3.monospacedDigit())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("VDOT improved from \(oldVDOT) to \(newVDOT)")

            Text("Update your training paces to match?")
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)

            Button {
                onAccept()
            } label: {
                Text("Update paces")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color.brand.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Updates your pace zones to use the new VDOT")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brand.accent.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct RecoveryAdviceBanner: View {
    let reason: String
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brand.caution)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery looks low today")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                    Text("We can swap today's hard session for an easy 5 km run.")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 6)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brand.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss recovery advice")
            }

            Button {
                onApply()
            } label: {
                Text("Swap to Easy")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color.brand.caution)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Replaces today's hard session with an easy 5 km run")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brand.caution.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct EmptyPlanPrompt: View {
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.brand.accent)
                .accessibilityHidden(true)

            Text("No race goal yet")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)

            Text("Create your first race goal and we'll build a personalised 16-week training plan.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brand.textSecondary)

            Button(action: onCreateTapped) {
                Text("Create Race Goal")
                    .bold()
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.brand.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Week Schedule View (full 16-week timeline)

struct WeekScheduleView: View {
    @Bindable var store: StoreOf<WeekSchedule>
    let allWeeks: [TrainingWeek]
    let currentVDOT: Double
    @FetchAll var allSessions: [PlannedSession]
    @FetchAll var completedAll: [CompletedWorkout]

    /// Weeks the user has expanded. Seeded with the current week the first
    /// time the view appears so it's always open by default; user toggles
    /// take precedence after that.
    @State private var expandedWeekIds: Set<UUID> = []
    @State private var hasSeededExpansion = false

    private var completedSessionIds: Set<UUID> {
        Set(completedAll.compactMap(\.plannedSessionId))
    }

    /// Calendar weekday of today, normalised so Mon=1 ... Sun=7 — matches
    /// PlannedSession.dayOfWeek so "today's row" can be highlighted.
    private var todayDayOfWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    /// Walks `allWeeks` in order and runs them through the phase enum so
    /// the timeline can be rendered as four phase blocks instead of a flat
    /// 16-week list. Cheap — runs once per render.
    private var phaseGroups: [(phase: TrainingPhase, weeks: [TrainingWeek])] {
        var groups: [(TrainingPhase, [TrainingWeek])] = []
        for week in allWeeks {
            if let last = groups.last, last.0 == week.phase {
                groups[groups.count - 1].1.append(week)
            } else {
                groups.append((week.phase, [week]))
            }
        }
        return groups
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(phaseGroups, id: \.phase) { group in
                    PhaseDivider(
                        phase: group.phase,
                        weekRange: weekRangeLabel(group.weeks)
                    )
                    VStack(spacing: 10) {
                        ForEach(group.weeks) { week in
                            WeekSection(
                                week: week,
                                sessions: allSessions.filter { $0.weekId == week.id }
                                                     .sorted { $0.dayOfWeek < $1.dayOfWeek },
                                completedIds: completedSessionIds,
                                isCurrent: isCurrentWeek(week),
                                isExpanded: expandedWeekIds.contains(week.id),
                                todayDayOfWeek: isCurrentWeek(week) ? todayDayOfWeek : nil,
                                currentVDOT: currentVDOT,
                                quickStartStatus: store.quickStartStatus,
                                onToggle: { toggle(week.id) },
                                onTap: { session in store.send(.sessionTapped(session)) },
                                onQuickStart: { session in
                                    store.send(.quickStartTapped(session, vdot: currentVDOT))
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.black)
        .navigationTitle("Full Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear(perform: seedExpansionIfNeeded)
    }

    private func seedExpansionIfNeeded() {
        guard !hasSeededExpansion else { return }
        if let current = allWeeks.first(where: isCurrentWeek) {
            expandedWeekIds.insert(current.id)
        }
        hasSeededExpansion = true
    }

    private func toggle(_ weekId: UUID) {
        if expandedWeekIds.contains(weekId) {
            expandedWeekIds.remove(weekId)
        } else {
            expandedWeekIds.insert(weekId)
        }
    }

    private func isCurrentWeek(_ week: TrainingWeek) -> Bool {
        TrainingWeek.current(in: [week]) != nil
    }

    private func weekRangeLabel(_ weeks: [TrainingWeek]) -> String {
        guard let first = weeks.first, let last = weeks.last else { return "" }
        if first.weekNumber == last.weekNumber {
            return "Week \(first.weekNumber)"
        }
        return "Weeks \(first.weekNumber)–\(last.weekNumber)"
    }
}

// MARK: - Phase divider

private struct PhaseDivider: View {
    let phase: TrainingPhase
    let weekRange: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(phase.tint)
                .frame(width: 3, height: 16)
            Text(phase.displayName.uppercased())
                .font(.caption.bold())
                .foregroundStyle(phase.tint)
                .tracking(1.2)
            Text("·")
                .foregroundStyle(Color.brand.textSecondary)
            Text(weekRange)
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phase.displayName) phase, \(weekRange)")
        .accessibilityAddTraits(.isHeader)
    }
}

private extension TrainingPhase {
    /// Maps each training phase onto a token from the zone palette so the
    /// 16-week arc visually warms up as intensity climbs.
    var tint: Color {
        switch self {
        case .base:  Color.brand.zone.easy        // sage
        case .build: Color.brand.zone.threshold   // mustard
        case .peak:  Color.brand.zone.interval    // burnt orange
        case .taper: Color.brand.accent           // lime
        }
    }
}

private struct WeekSection: View {
    let week: TrainingWeek
    let sessions: [PlannedSession]
    let completedIds: Set<UUID>
    let isCurrent: Bool
    let isExpanded: Bool
    /// Set when this section is the current week — used to mark today's
    /// row with a lime border and a Start button. nil for past/future weeks.
    let todayDayOfWeek: Int?
    let currentVDOT: Double
    let quickStartStatus: WeekSchedule.State.QuickStartStatus
    let onToggle: () -> Void
    let onTap: (PlannedSession) -> Void
    let onQuickStart: (PlannedSession) -> Void

    private var sessionCount: Int { sessions.filter { $0.sessionType != .rest }.count }
    private var completedCount: Int {
        sessions.filter { completedIds.contains($0.id) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        if session.sessionType == .rest {
                            restRow(session)
                        } else {
                            sessionRow(session)
                        }
                    }
                }
                .padding(.leading, 22) // align with header text after chevron
                .transition(.opacity)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.brand.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Week \(week.weekNumber)")
                            .font(.subheadline.bold())
                            .foregroundStyle(isCurrent ? Color.brand.accent : .white)
                        if isCurrent {
                            Text("THIS WEEK")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brand.accent.opacity(0.2))
                                .foregroundStyle(Color.brand.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(completedCount) of \(sessionCount) done")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }

                Spacer()

                // Hero number: weekly volume. Eye should be able to track
                // the volume curve down the page without reading subtitles.
                Text("\(week.targetWeeklyKm, format: .number.precision(.fractionLength(0))) km")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isCurrent ? Color.brand.accent : .white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(Color.brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week \(week.weekNumber), \(week.phase.displayName), \(completedCount) of \(sessionCount) completed, \(Int(week.targetWeeklyKm)) kilometres")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
        .accessibilityAddTraits(isExpanded ? [.isHeader, .isSelected] : .isHeader)
    }

    // MARK: - Session row (active days)

    @ViewBuilder
    private func sessionRow(_ session: PlannedSession) -> some View {
        let isToday = todayDayOfWeek == session.dayOfWeek
        let isCompleted = completedIds.contains(session.id)
        let isSending: Bool = {
            guard case let .sending(id) = quickStartStatus else { return false }
            return id == session.id
        }()

        Button {
            onTap(session)
        } label: {
            HStack(spacing: 14) {
                // Leading stroke SF Symbol in the session-type tint.
                // Outlined style reads as instrument, not decoration.
                Image(systemName: session.sessionType.symbolName)
                    .font(.title3)
                    .foregroundStyle(Color(hex: session.sessionType.colorHex))
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(dayLabel(session.dayOfWeek))
                            .font(.caption.bold())
                            .foregroundStyle(Color(hex: session.sessionType.colorHex))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(hex: session.sessionType.colorHex).opacity(0.15))
                            )
                        Text(session.sessionType.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    if let subtitle = paceSubtitle(for: session) {
                        Text(subtitle)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.brand.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                trailing(
                    session: session,
                    isToday: isToday,
                    isCompleted: isCompleted,
                    isSending: isSending
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .background(Color.brand.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isToday ? Color.brand.accent : Color.clear,
                        lineWidth: isToday ? 1.5 : 0
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(opacity(isCompleted: isCompleted))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: session, isToday: isToday, isCompleted: isCompleted))
    }

    @ViewBuilder
    private func trailing(
        session: PlannedSession,
        isToday: Bool,
        isCompleted: Bool,
        isSending: Bool
    ) -> some View {
        if isCompleted {
            VStack(alignment: .trailing, spacing: 4) {
                kmText(session)
                Image(systemName: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.brand.success)
            }
        } else if isToday {
            // Today's row gets a dedicated Start button — bypasses the
            // editor and pushes the workout straight to the Watch.
            Button {
                onQuickStart(session)
            } label: {
                HStack(spacing: 4) {
                    if isSending {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.black)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.caption.bold())
                    }
                    Text(isSending ? "Sending" : "Start")
                        .font(.caption.bold())
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 32)
                .background(Color.brand.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSending)
            .accessibilityLabel("Start \(session.sessionType.displayName) on Apple Watch")
        } else {
            VStack(alignment: .trailing, spacing: 4) {
                kmText(session)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.brand.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func kmText(_ session: PlannedSession) -> some View {
        if let km = session.targetDistanceKm {
            Text("\(km, format: .number.precision(.fractionLength(0...1))) km")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.brand.textSecondary)
        } else if let min = session.targetDurationMin {
            Text("\(min) min")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.brand.textSecondary)
        }
    }

    // MARK: - Rest row (quieter)

    @ViewBuilder
    private func restRow(_ session: PlannedSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: session.sessionType.symbolName)
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Text("\(dayLabel(session.dayOfWeek)) · Rest")
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 14)
        .opacity(0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayLabel(session.dayOfWeek)), rest day")
    }

    // MARK: - Helpers

    /// Pace zone description — only available for sessions that have a
    /// targetPaceZone set; for past weeks it's an honest qualitative cue.
    /// For the *current week*, the live pace is rendered on the Plan tab's
    /// session card; here we keep it qualitative so the schedule stays
    /// scannable across phases.
    private func paceSubtitle(for session: PlannedSession) -> String? {
        guard let zone = session.targetPaceZone else { return nil }
        if isCurrent, currentVDOT > 0 {
            let range = VDOTCalculator.paceRange(for: zone, vdot: currentVDOT)
            return "\(zoneName(zone)) · \(range.formatted())"
        }
        return zoneName(zone)
    }

    private func zoneName(_ zone: PaceZoneName) -> String {
        switch zone {
        case .easy:       "Easy zone"
        case .marathon:   "Marathon zone"
        case .threshold:  "Threshold zone"
        case .interval:   "Interval zone"
        case .repetition: "Repetition zone"
        }
    }

    private func opacity(isCompleted: Bool) -> Double {
        if isCompleted { return 0.6 }
        if isCurrent { return 1.0 }
        return 0.85
    }

    private func accessibilityLabel(for session: PlannedSession, isToday: Bool, isCompleted: Bool) -> String {
        var parts: [String] = [dayLabel(session.dayOfWeek), session.sessionType.displayName]
        if isToday { parts.append("today") }
        if let km = session.targetDistanceKm {
            parts.append("\(Int(km)) kilometres")
        } else if let min = session.targetDurationMin {
            parts.append("\(min) minutes")
        }
        if let zone = session.targetPaceZone {
            parts.append(zoneName(zone))
        }
        if isCompleted { parts.append("completed") }
        return parts.joined(separator: ", ")
    }

    private func dayLabel(_ day: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = day - 1
        return (idx >= 0 && idx < days.count) ? days[idx] : "?"
    }
}
