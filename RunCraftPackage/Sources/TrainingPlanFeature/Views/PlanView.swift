import ComposableArchitecture
import DesignSystem
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
                    if let goal = activeGoal, !goal.isPlaceholder {
                        Button {
                            store.send(.countdownTapped)
                        } label: {
                            RaceCountdownRing(goal: goal)
                                .padding(.top, 8)
                        }
                        .buttonStyle(.plain)

                        upgradeAndRecoveryBanners

                        // This Week comes BEFORE the pace zones — the runner's
                        // daily question is "what do I run today?" not "what
                        // are my paces?". Paces are reference; the schedule
                        // is the action. Apple Workout follows the same
                        // hierarchy.
                        weekOrPreviewContent

                        if let zones = store.paceZones {
                            PaceZonesSummaryCard(zones: zones) { zone in
                                store.send(.paceChipTapped(zone))
                            }
                        }
                    } else if let goal = activeGoal, goal.isPlaceholder {
                        BaseTrainingBanner(vdot: store.currentVDOT)
                            .padding(.top, 8)

                        upgradeAndRecoveryBanners

                        weekOrPreviewContent

                        if let zones = store.paceZones {
                            PaceZonesSummaryCard(zones: zones) { zone in
                                store.send(.paceChipTapped(zone))
                            }
                        }

                        AddRaceGoalLink {
                            store.send(.addRaceGoalButtonTapped)
                        }
                    } else {
                        EmptyPlanPrompt(
                            onAddRaceGoal: { store.send(.addRaceGoalButtonTapped) },
                            onSetUpVDOT: { store.send(.setupVDOTButtonTapped) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color.brand.background)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let goal = activeGoal {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if !goal.isPlaceholder {
                                Button {
                                    store.send(.recalculateVDOTRequested)
                                } label: {
                                    Label("Edit goal / recalculate", systemImage: "pencil")
                                }
                            }
                            Button {
                                store.send(.adjustVDOTRequested)
                            } label: {
                                Label("Adjust VDOT manually", systemImage: "slider.horizontal.3")
                            }
                            Button {
                                store.send(.adjustTrainingDaysRequested(goal))
                            } label: {
                                Label("Adjust training days", systemImage: "calendar.badge.checkmark")
                            }
                            Divider()
                            Button(role: .destructive) {
                                store.send(.deletePlanRequested(isPlaceholder: goal.isPlaceholder))
                            } label: {
                                Label(
                                    goal.isPlaceholder ? "Remove VDOT setup" : "Delete plan",
                                    systemImage: "trash"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.brand.accent)
                        }
                    }
                }
            }
            .task { await store.send(.onAppear).finish() }
            .sheet(item: $store.scope(state: \.destination?.setupRaceGoal, action: \.destination.setupRaceGoal)) { setupStore in
                SetupRaceGoalView(store: setupStore)
            }
            .sheet(item: $store.scope(state: \.destination?.setupVDOT, action: \.destination.setupVDOT)) { setupStore in
                SetupVDOTView(store: setupStore)
            }
            .sheet(item: $store.scope(state: \.destination?.adjustVDOT, action: \.destination.adjustVDOT)) { adjustStore in
                AdjustVDOTView(store: adjustStore)
            }
            .sheet(item: $store.scope(state: \.destination?.adjustTrainingDays, action: \.destination.adjustTrainingDays)) { adjustStore in
                AdjustTrainingDaysView(store: adjustStore)
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

    /// VDOT-upgrade and recovery-advice banners — shown above the week's
    /// sessions for both a real race goal (State C) and Base Training
    /// (State B), since both have a current VDOT and a "today" to evaluate.
    @ViewBuilder
    private var upgradeAndRecoveryBanners: some View {
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

        if store.healthPermissionLost {
            HealthPermissionBanner(
                onGrantAccess: { store.send(.requestHealthAuthorization) },
                onDismiss: { store.send(.dismissHealthPermissionBanner) }
            )
        }
    }

    @ViewBuilder
    private var weekOrPreviewContent: some View {
        if let currentWeek = currentWeek {
            // `weekNumber == 0` is the State C gap-filler: today falls
            // before the periodized plan's week 1. Surface when the real
            // plan kicks in above this week's Base Training sessions.
            if currentWeek.weekNumber == 0, let planStart = planWeek1StartDate {
                PlanGapBanner(planStartDate: planStart)
            }
            WeekSessionsSection(
                week: currentWeek,
                vdot: store.currentVDOT,
                watchAvailable: store.watchAvailable,
                quickStartSendingSessionId: store.quickStartSendingSessionId,
                onSessionTap: { store.send(.sessionTapped($0)) },
                onQuickStart: { store.send(.quickStartSession($0)) },
                onSwap: { store.send(.swapSession($0, to: $1, variantNote: $2)) }
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
    }

    private var currentWeek: TrainingWeek? {
        TrainingWeek.current(in: allWeeks)
    }

    /// Start date of the periodized plan's week 1, used by `PlanGapBanner`
    /// while the `weekNumber == 0` gap-filler week is current.
    private var planWeek1StartDate: Date? {
        allWeeks.first { $0.weekNumber == 1 }?.startDate
    }

    /// The next `TrainingWeek` to begin, used when `currentWeek` is nil
    /// because the runner set a race more than 16 weeks out. Returns the
    /// earliest week whose `startDate` is still in the future.
    private var firstUpcomingWeek: TrainingWeek? {
        guard currentWeek == nil else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        return allWeeks
            .filter { $0.weekNumber >= 1 && $0.startDate > today }
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
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

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
    let watchAvailable: Bool
    let quickStartSendingSessionId: UUID?
    let onSessionTap: (PlannedSession) -> Void
    let onQuickStart: (PlannedSession) -> Void
    let onSwap: (PlannedSession, SessionType, String?) -> Void
    @FetchAll var allSessions: [PlannedSession]
    @FetchAll var completedThisWeek: [CompletedWorkout]

    private var sessions: [PlannedSession] {
        allSessions.filter { $0.weekId == week.id }.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    /// `CompletedWorkout` rows grouped by the `PlannedSession` they were
    /// matched to — see `SessionActuals`.
    private var completedBySessionId: [UUID: [CompletedWorkout]] {
        Dictionary(grouping: completedThisWeek.filter { $0.plannedSessionId != nil }) { $0.plannedSessionId! }
    }

    private var todayDayOfWeek: Int {
        PlannedSession.dayOfWeek(for: Date())
    }

    private var adherence: (completed: Int, planned: Int) {
        let planned = sessions.filter { $0.sessionType != .rest }
        let completed = planned.filter { completedBySessionId[$0.id] != nil }
        return (completed.count, planned.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(week.weekNumber == 0 ? "This Week · Base Training" : "Week \(week.weekNumber) · \(week.phase.displayName)")
                    .font(.headline)
                    .foregroundStyle(Color.brand.textPrimary)
                Spacer()
                if adherence.planned > 0 && adherence.completed > 0 {
                    Text("\(adherence.completed)/\(adherence.planned)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brand.accent, in: Capsule())
                }
                Text("\(week.targetWeeklyKm, format: .number.precision(.fractionLength(0))) km")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.accent)
            }

            ForEach(sessions) { session in
                let actuals = completedBySessionId[session.id].flatMap(SessionActuals.init)
                if session.sessionType == .rest {
                    RestSessionLine(session: session, actuals: actuals)
                } else {
                    SessionCard(
                        session: session,
                        vdot: vdot,
                        actuals: actuals,
                        isToday: session.dayOfWeek == todayDayOfWeek,
                        watchAvailable: watchAvailable,
                        isSending: quickStartSendingSessionId == session.id,
                        onTap: { onSessionTap(session) },
                        onQuickStart: { onQuickStart(session) },
                        onSwap: { newType, note in onSwap(session, newType, note) }
                    )
                }
            }
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
    @FetchAll var allSessions: [PlannedSession]
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

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
        let runSessions = allSessions
            .filter { $0.weekId == week.id && $0.sessionType != .rest }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
        VStack(spacing: 8) {
            ForEach(runSessions) { session in
                PreviewSessionRow(session: session, vdot: vdot, paceUnit: paceUnit)
            }
        }
        .opacity(0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Week 1 preview, \(runSessions.count) sessions")
    }
}

/// Shown above `WeekSessionsSection` for State C's `weekNumber == 0`
/// gap-filler week — the runner's race is more than 16 weeks out (or the
/// race date has passed), so today's "Base Training" session is shown
/// alongside a heads-up about when the periodized plan starts.
private struct PlanGapBanner: View {
    let planStartDate: Date

    private var daysUntilStart: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: planStartDate)
        ).day ?? 0
    }

    var body: some View {
        if daysUntilStart > 0 {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(Color.brand.caution)
                    .frame(width: 36, height: 36)
                    .background(Color.brand.caution.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your 16-week plan starts in \(daysUntilStart) day\(daysUntilStart == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundStyle(Color.brand.textPrimary)
                    Text(planStartDate, format: .dateTime.weekday(.wide).month().day())
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
        weekdayLabel(session.dayOfWeek)
    }

    private var subtitle: String {
        var pieces: [String] = []
        if let km = session.targetDistanceKm {
            pieces.append(PaceFormatting.distance(metres: km * 1_000, unit: paceUnit))
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
    /// "What actually happened," from the matched `CompletedWorkout`(s).
    /// Drives the completed state — non-nil means this session is done.
    let actuals: SessionActuals?
    let isToday: Bool
    let watchAvailable: Bool
    let isSending: Bool
    let onTap: () -> Void
    let onQuickStart: () -> Void
    let onSwap: (SessionType, String?) -> Void
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    private var isCompleted: Bool { actuals != nil }

    var body: some View {
        WorkoutCard(
            palette: SessionPalette.palette(for: session.sessionType),
            symbolName: session.sessionType.symbolName,
            title: cardTitle,
            subtitle: cardSubtitle,
            actualLine: actuals.map { "Actual: \($0.displayText(unit: paceUnit))" },
            trailing: trailingKind,
            isLoading: isSending,
            action: onTap,
            secondary: onQuickStart
        )
        .opacity(isCompleted ? 0.65 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .contextMenu {
            let alternatives = session.sessionType.alternatives
            if !alternatives.isEmpty && !isCompleted {
                ForEach(alternatives) { alt in
                    Button {
                        onSwap(alt.sessionType, alt.variantNote)
                    } label: {
                        Label(alt.title, systemImage: alt.sessionType.symbolName)
                    }
                }
            }
        }
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
        if isToday && watchAvailable { return .play }
        return .chevron
    }

    private var accessibilityLabel: String {
        var parts: [String] = [dayLabel, session.sessionType.displayName]
        if isToday { parts.append("today") }
        if let sub = cardSubtitle { parts.append(sub) }
        if let actuals {
            parts.append("completed, actual \(actuals.displayText(unit: paceUnit))")
        }
        return parts.joined(separator: ", ")
    }

    private var dayLabel: String {
        weekdayLabel(session.dayOfWeek)
    }
}

/// Rest days don't get a full card — they're a quiet line so the eye
/// skips past them to the actual training. Unless training happened
/// anyway (sync-back matched a `CompletedWorkout` to this rest day), in
/// which case that's surfaced instead of staying silent about it.
private struct RestSessionLine: View {
    let session: PlannedSession
    let actuals: SessionActuals?
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.sessionType.symbolName)
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(dayLabel) · Rest")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.textSecondary)
                if let actuals {
                    Text("Logged: \(actuals.displayText(unit: paceUnit))")
                        .font(.caption)
                        .foregroundStyle(Color.brand.accent)
                }
            }
            Spacer()
            if actuals != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.brand.success)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .opacity(actuals == nil ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "\(dayLabel), rest day"
        if let actuals {
            label += ", but logged \(actuals.displayText(unit: paceUnit))"
        }
        return label
    }

    private var dayLabel: String {
        weekdayLabel(session.dayOfWeek)
    }
}

/// Non-interactive header for State B ("Base Training") — visually distinct
/// from `RaceCountdownRing`: no ring, no countdown, no date, not a `Button`.
private struct BaseTrainingBanner: View {
    let vdot: Double

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.brand.accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(Color.brand.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Base Training")
                    .font(.headline)
                    .foregroundStyle(Color.brand.textPrimary)
                Text("VDOT \(vdot, format: .number.precision(.fractionLength(1))) · no race goal yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Bottom-of-screen link for State B, inviting the runner to graduate
/// Base Training into a full 16-week plan once they have a race in mind.
private struct AddRaceGoalLink: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Label("Add a Race Goal", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
            }
            .foregroundStyle(Color.brand.accent)
            .padding()
            .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyPlanPrompt: View {
    let onAddRaceGoal: () -> Void
    let onSetUpVDOT: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.brand.accent)
                .accessibilityHidden(true)

            Text("No training plan yet")
                .font(.title2)
                .bold()
                .foregroundStyle(Color.brand.textPrimary)

            Text("Add a race goal for a personalised 16-week plan, or set up your VDOT for a rolling base training week.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brand.textSecondary)

            VStack(spacing: 12) {
                Button(action: onAddRaceGoal) {
                    Text("Add Race Goal")
                        .bold()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.brand.accent)
                        .clipShape(Capsule())
                }

                Button(action: onSetUpVDOT) {
                    Text("Set Up VDOT")
                        .bold()
                        .foregroundStyle(Color.brand.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(Capsule().stroke(Color.brand.accent, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 60)
    }
}
