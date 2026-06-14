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
        PlannedSession.dayOfWeek(for: Date())
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
        weekdayLabel(session.dayOfWeek)
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
        weekdayLabel(session.dayOfWeek)
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

            SampleWeekPreview()
                .padding(.top, 12)
        }
        .padding(.top, 60)
    }
}

/// Gives a runner with no race goal a concrete look at what RunCraft
/// generates — the Base-phase week-1 template, rendered with the same
/// dimmed `PreviewSessionRow` used for the "race far in the future" case.
/// No VDOT yet, so paces are omitted; only structure (day, type, distance)
/// is shown. Labelled "Example" so it doesn't read as the runner's own data.
private struct SampleWeekPreview: View {
    private let sessions = TrainingPlanGenerator.sampleWeek1Sessions()
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EXAMPLE")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.brand.accent)
                Text("Example week · \(TrainingPhase.base.displayName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand.textSecondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(sessions.filter { $0.sessionType != .rest }) { session in
                    PreviewSessionRow(session: session, vdot: 0, paceUnit: paceUnit)
                }
            }
            .opacity(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
