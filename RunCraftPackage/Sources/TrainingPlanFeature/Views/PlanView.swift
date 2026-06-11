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
                VStack(spacing: 20) {
                    if let goal = activeGoal {
                        Button {
                            store.send(.countdownTapped)
                        } label: {
                            RaceCountdownRing(goal: goal)
                                .padding(.top, 8)
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

                        // This Week comes BEFORE the pace zones — the runner's
                        // daily question is "what do I run today?" not "what
                        // are my paces?". Paces are reference; the schedule
                        // is the action. Apple Workout follows the same
                        // hierarchy.
                        if let currentWeek = currentWeek {
                            WeekSessionsSection(
                                week: currentWeek,
                                vdot: store.currentVDOT,
                                quickStartSendingSessionId: store.quickStartSendingSessionId,
                                onSessionTap: { store.send(.sessionTapped($0)) },
                                onQuickStart: { store.send(.quickStartSession($0)) }
                            )
                        } else if let upcoming = firstUpcomingWeek {
                            // No current week but the plan exists — runner is
                            // in the "race is more than 16 weeks out" gap.
                            // Show when the plan kicks in plus a greyed-out
                            // preview of week 1 so the page doesn't look empty.
                            PrePlanPreviewSection(
                                week: upcoming,
                                vdot: store.currentVDOT
                            )
                        }

                        if let zones = store.paceZones {
                            PaceZonesSummaryCard(zones: zones) { zone in
                                store.send(.paceChipTapped(zone))
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
            .background(Color.brand.background)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if store.hasGoal {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                store.send(.recalculateVDOTRequested)
                            } label: {
                                Label("Edit goal / recalculate", systemImage: "pencil")
                            }
                            Button {
                                store.send(.adjustVDOTRequested)
                            } label: {
                                Label("Adjust VDOT manually", systemImage: "slider.horizontal.3")
                            }
                            Divider()
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
            .sheet(item: $store.scope(state: \.destination?.adjustVDOT, action: \.destination.adjustVDOT)) { adjustStore in
                AdjustVDOTView(store: adjustStore)
            }
            .alert($store.scope(state: \.destination?.deleteConfirm, action: \.destination.deleteConfirm))
            .alert($store.scope(state: \.quickStartAlert, action: \.quickStartAlert))
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

    /// The next `TrainingWeek` to begin, used when `currentWeek` is nil
    /// because the runner set a race more than 16 weeks out. Returns the
    /// earliest week whose `startDate` is still in the future.
    private var firstUpcomingWeek: TrainingWeek? {
        guard currentWeek == nil else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        return allWeeks
            .filter { $0.startDate > today }
            .min(by: { $0.startDate < $1.startDate })
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
        // Slimmer hero so This Week clears the fold — 120pt ring (down from
        // 160) and the goal name / phase / date collapsed into a single
        // metadata line. The countdown is still the focal point but no
        // longer eats the whole first screen.
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 10)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        Color.brand.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: ringProgress)

                VStack(spacing: 0) {
                    Text("\(max(goal.daysUntilRace, 0))")
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.brand.textPrimary)
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(ringAccessibilityLabel)

            VStack(alignment: .leading, spacing: 6) {
                Text(goal.name)
                    .font(.headline)
                    .foregroundStyle(Color.brand.textPrimary)
                    .lineLimit(2)

                if let ctx = phaseContext {
                    Text("Week \(ctx.week) of 16 · \(ctx.phase.displayName)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.brand.accent)
                }

                Text(goal.targetDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
            }

            Spacer(minLength: 0)
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
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

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
            PaceChip(label: zone.letter, pace: zones[zone].formatted(unit: paceUnit), color: Self.color(for: zone))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(zone.fullName) pace, \(zones[zone].formatted(unit: paceUnit))")
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
                .foregroundStyle(Color.brand.textPrimary)
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
    let quickStartSendingSessionId: UUID?
    let onSessionTap: (PlannedSession) -> Void
    let onQuickStart: (PlannedSession) -> Void
    @FetchAll(PlannedSession.none) var sessions: [PlannedSession]
    @FetchAll var completedThisWeek: [CompletedWorkout]

    private var completedSessionIds: Set<UUID> {
        Set(completedThisWeek.compactMap(\.plannedSessionId))
    }

    private var todayDayOfWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Week \(week.weekNumber) · \(week.phase.displayName)")
                    .font(.headline)
                    .foregroundStyle(Color.brand.textPrimary)
                Spacer()
                Text("\(week.targetWeeklyKm, format: .number.precision(.fractionLength(0))) km")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.accent)
            }

            ForEach(sessions) { session in
                if session.sessionType == .rest {
                    RestSessionLine(session: session)
                } else {
                    SessionCard(
                        session: session,
                        vdot: vdot,
                        isCompleted: completedSessionIds.contains(session.id),
                        isToday: session.dayOfWeek == todayDayOfWeek,
                        isSending: quickStartSendingSessionId == session.id,
                        onTap: { onSessionTap(session) },
                        onQuickStart: { onQuickStart(session) }
                    )
                }
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

// MARK: - Pre-plan preview

/// Surface for the "race is more than 16 weeks out" gap. Tells the runner
/// when the plan kicks in and previews week 1 in a muted style so they
/// know what's coming without the affordance to start it early.
///
/// No quick-start, no tap-into-editor — these sessions live in the future.
private struct PrePlanPreviewSection: View {
    let week: TrainingWeek
    let vdot: Double
    @FetchAll(PlannedSession.none) var sessions: [PlannedSession]
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

    private var daysUntilStart: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: week.startDate)
        ).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            startBanner
            previewHeader
            previewList
        }
        .task(id: week.id) { await loadSessions() }
    }

    /// Hero callout — the most important piece of info on this screen
    /// when the plan hasn't started. Uses caution-tint so it reads as
    /// "heads up" rather than "ready to go."
    private var startBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(Color.brand.caution)
                .frame(width: 36, height: 36)
                .background(Color.brand.caution.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Plan starts in \(daysUntilStart) day\(daysUntilStart == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundStyle(Color.brand.textPrimary)
                Text(week.startDate, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brand.caution.opacity(0.3), lineWidth: 1)
        )
    }

    private var previewHeader: some View {
        HStack {
            Text("Week 1 preview · \(week.phase.displayName)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brand.textSecondary)
            Spacer()
            Text("\(week.targetWeeklyKm, format: .number.precision(.fractionLength(0))) km")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.brand.textSecondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    /// Sessions render at 0.55 opacity to read as "not actionable yet."
    /// Skip rest days for visual density — the preview is about giving
    /// the runner a feel for the work, not a day-by-day shopping list.
    @ViewBuilder
    private var previewList: some View {
        let runSessions = sessions.filter { $0.sessionType != .rest }
        VStack(spacing: 8) {
            ForEach(runSessions) { session in
                PreviewSessionRow(session: session, vdot: vdot, paceUnit: paceUnit)
            }
        }
        .opacity(0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Week 1 preview, \(runSessions.count) sessions")
    }

    private func loadSessions() async {
        _ = await withErrorReporting {
            try await $sessions.load(
                PlannedSession
                    .where { $0.weekId.eq(week.id) }
                    .order(by: \.dayOfWeek)
            )
        }
    }
}

/// Lightweight row for the pre-plan preview. Deliberately simpler than
/// `SessionCard` — no play button, no chevron, no quick-start. The whole
/// list is rendered at reduced opacity by the parent.
private struct PreviewSessionRow: View {
    let session: PlannedSession
    let vdot: Double
    let paceUnit: PaceUnit

    private var dayLabel: String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = session.dayOfWeek - 1
        guard idx >= 0, idx < days.count else { return "" }
        return days[idx]
    }

    private var subtitle: String {
        var pieces: [String] = []
        if let km = session.targetDistanceKm {
            pieces.append("\(km.formatted(.number.precision(.fractionLength(0...1)))) km")
        } else if let min = session.targetDurationMin {
            pieces.append("\(min) min")
        }
        if let zone = session.targetPaceZone, vdot > 0 {
            let range = VDOTCalculator.paceRange(for: zone, vdot: vdot)
            pieces.append(range.formatted(unit: paceUnit))
        }
        return pieces.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.sessionType.symbolName)
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(dayLabel) · \(session.sessionType.displayName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SessionCard: View {
    let session: PlannedSession
    let vdot: Double
    let isCompleted: Bool
    let isToday: Bool
    let isSending: Bool
    let onTap: () -> Void
    let onQuickStart: () -> Void
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

    var body: some View {
        WorkoutCard(
            palette: SessionPalette.palette(for: session.sessionType),
            symbolName: session.sessionType.symbolName,
            title: cardTitle,
            subtitle: cardSubtitle,
            trailing: trailingKind,
            isLoading: isSending,
            action: onTap,
            secondary: onQuickStart
        )
        .opacity(isCompleted ? 0.65 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cardTitle: String {
        "\(dayLabel) · \(session.sessionType.displayName)"
    }

    /// Live pace + km/min + planner notes, e.g.
    /// "8 km · 5:30–6:10 /km · 5×1000m". Notes (when present — usually
    /// for hard sessions like intervals or auto-downgrades) are appended
    /// last so the runner sees the *structural* context their plan was
    /// generated with.
    private var cardSubtitle: String? {
        var pieces: [String] = []
        if let km = session.targetDistanceKm {
            pieces.append("\(km.formatted(.number.precision(.fractionLength(0...1)))) km")
        } else if let min = session.targetDurationMin {
            pieces.append("\(min) min")
        }
        if let zone = session.targetPaceZone, vdot > 0 {
            let range = VDOTCalculator.paceRange(for: zone, vdot: vdot)
            pieces.append(range.formatted(unit: paceUnit))
        }
        if !session.notes.isEmpty {
            pieces.append(session.notes)
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: " · ")
    }

    private var trailingKind: WorkoutCard<EmptyView>.Trailing {
        if isCompleted { return .check }
        if isToday { return .play }
        return .chevron
    }

    private var accessibilityLabel: String {
        var parts: [String] = [dayLabel, session.sessionType.displayName]
        if isToday { parts.append("today") }
        if let sub = cardSubtitle { parts.append(sub) }
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

/// Rest days don't get a full card — they're a quiet line so the eye
/// skips past them to the actual training.
private struct RestSessionLine: View {
    let session: PlannedSession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.sessionType.symbolName)
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
                .frame(width: 32)
            Text("\(dayLabel) · Rest")
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .opacity(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayLabel), rest day")
    }

    private var dayLabel: String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = session.dayOfWeek - 1
        guard idx >= 0, idx < days.count else { return "" }
        return days[idx]
    }
}

/// Maps each SessionType onto a `WorkoutCardPalette` — keeps the palette
/// lookup centralised so the Plan tab, Full Schedule, and any future
/// session-row consumer stay visually consistent.
enum SessionPalette {
    static func palette(for type: SessionType) -> WorkoutCardPalette {
        switch type {
        case .easy:       .easy
        case .tempo:      .threshold
        case .interval:   .interval
        case .long:       .long
        case .repetition: .repetition
        case .rest:       .rest
        }
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
                    .foregroundStyle(Color.brand.textPrimary)
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
                        .foregroundStyle(Color.brand.textPrimary)
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
                .foregroundStyle(Color.brand.textPrimary)

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
        .background(Color.brand.background)
        .navigationTitle("Full Schedule")
        .navigationBarTitleDisplayMode(.inline)
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
    /// Resolves a SessionType onto the brand zone palette (dynamic per
    /// light/dark). Keeps Full Schedule row tints adapting cleanly to
    /// both modes instead of using SessionType.colorHex (static
    /// Material swatches that fail AA on white).
    fileprivate static func sessionColor(_ type: SessionType) -> Color {
        switch type {
        case .easy:       Color.brand.zone.easy
        case .tempo:      Color.brand.zone.threshold
        case .interval:   Color.brand.zone.interval
        case .long:       Color.brand.zone.marathon
        case .repetition: Color.brand.zone.repetition
        case .rest:       Color.brand.textSecondary
        }
    }


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
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

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
            // Map the session type onto the dynamic brand zone palette so
            // tints adapt for light + dark instead of using the static
            // Material hex tied to SessionType.colorHex (those wash out
            // on white backgrounds).
            let tint = Self.sessionColor(session.sessionType)
            HStack(spacing: 14) {
                // Leading stroke SF Symbol in the session-type tint.
                // Outlined style reads as instrument, not decoration.
                Image(systemName: session.sessionType.symbolName)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(dayLabel(session.dayOfWeek))
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(tint.opacity(0.15))
                            )
                        Text(session.sessionType.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.brand.textPrimary)
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
            return "\(zoneName(zone)) · \(range.formatted(unit: paceUnit))"
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
