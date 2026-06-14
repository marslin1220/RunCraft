import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine

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

    /// `CompletedWorkout` rows grouped by the `PlannedSession` they were
    /// matched to. A session can have more than one entry (same-day
    /// double-workout) — see `SessionActuals`.
    private var completedBySessionId: [UUID: [CompletedWorkout]] {
        Dictionary(grouping: completedAll.filter { $0.plannedSessionId != nil }) { $0.plannedSessionId! }
    }

    private var todayDayOfWeek: Int {
        PlannedSession.dayOfWeek(for: Date())
    }

    /// `allWeeks` filtered to the periodized weeks 1...16, excluding the
    /// `weekNumber == 0` gap-filler rolling week (State C's pre-plan
    /// "Base Training" week) so Full Schedule shows exactly the real plan.
    private var planWeeks: [TrainingWeek] {
        allWeeks.filter { $0.weekNumber >= 1 }
    }

    /// The `weekNumber == 0` gap-filler rolling week — present only while
    /// "today" falls before the periodized plan's week 1 (race far enough
    /// out that the 16-week buildup hasn't started yet). Shown in its own
    /// "Foundation · Ongoing" section above the periodized phases so Full
    /// Schedule has continuity with the Plan tab's "This Week" section.
    private var gapWeek: TrainingWeek? {
        allWeeks.first { $0.weekNumber == 0 }
    }

    /// Walks `planWeeks` in order and runs them through the phase enum so
    /// the timeline can be rendered as four phase blocks instead of a flat
    /// 16-week list. Cheap — runs once per render.
    private var phaseGroups: [(phase: TrainingPhase, weeks: [TrainingWeek])] {
        var groups: [(TrainingPhase, [TrainingWeek])] = []
        for week in planWeeks {
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
                if let gapWeek {
                    FoundationDivider()
                    WeekSection(
                        week: gapWeek,
                        sessions: allSessions.filter { $0.weekId == gapWeek.id }
                                             .sorted { $0.dayOfWeek < $1.dayOfWeek },
                        completedBySessionId: completedBySessionId,
                        isCurrent: true,
                        isExpanded: expandedWeekIds.contains(gapWeek.id),
                        todayDayOfWeek: todayDayOfWeek,
                        currentVDOT: currentVDOT,
                        quickStartStatus: store.quickStartStatus,
                        onToggle: { toggle(gapWeek.id) },
                        onTap: { session, isToday in
                            store.send(.sessionTapped(session, isToday: isToday))
                        },
                        onQuickStart: { session in
                            store.send(.quickStartTapped(session, vdot: currentVDOT))
                        }
                    )
                }
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
                                completedBySessionId: completedBySessionId,
                                isCurrent: isCurrentWeek(week),
                                isExpanded: expandedWeekIds.contains(week.id),
                                todayDayOfWeek: isCurrentWeek(week) ? todayDayOfWeek : nil,
                                currentVDOT: currentVDOT,
                                quickStartStatus: store.quickStartStatus,
                                onToggle: { toggle(week.id) },
                                onTap: { session, isToday in
                                    store.send(.sessionTapped(session, isToday: isToday))
                                },
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
        if let gapWeek {
            expandedWeekIds.insert(gapWeek.id)
        } else if let current = planWeeks.first(where: isCurrentWeek) {
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

/// Header for the `weekNumber == 0` gap-filler week — visually matches
/// `PhaseDivider` (same rail + caption styling) but isn't one of the four
/// periodized `TrainingPhase`s, so it gets its own fixed "Foundation ·
/// Ongoing" label rather than a phase name + week range.
private struct FoundationDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(TrainingPhase.base.tint)
                .frame(width: 3, height: 16)
            Text("FOUNDATION")
                .font(.caption.bold())
                .foregroundStyle(TrainingPhase.base.tint)
                .tracking(1.2)
            Text("·")
                .foregroundStyle(Color.brand.textSecondary)
            Text("Ongoing")
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Foundation training, ongoing")
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
        case .fartlek:    Color.brand.zone.fartlek
        case .mixed:      Color.brand.zone.mixed
        }
    }


    let week: TrainingWeek
    let sessions: [PlannedSession]
    let completedBySessionId: [UUID: [CompletedWorkout]]
    let isCurrent: Bool
    let isExpanded: Bool
    /// Set when this section is the current week — used to mark today's
    /// row with a lime border and a Start button. nil for past/future weeks.
    let todayDayOfWeek: Int?
    let currentVDOT: Double
    let quickStartStatus: WeekSchedule.State.QuickStartStatus
    let onToggle: () -> Void
    let onTap: (PlannedSession, Bool) -> Void
    let onQuickStart: (PlannedSession) -> Void
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

    private var completedIds: Set<UUID> { Set(completedBySessionId.keys) }
    private var sessionCount: Int { sessions.filter { $0.sessionType != .rest }.count }
    /// Rest days don't count toward "X of Y done" — but a rest day can
    /// still have a `CompletedWorkout` matched to it (training happened on
    /// a planned rest day, see `restRow`'s "Logged" line), so this must be
    /// filtered the same way as `sessionCount` to avoid e.g. "5 of 4 done".
    private var completedCount: Int {
        sessions.filter { $0.sessionType != .rest && completedIds.contains($0.id) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        let actuals = completedBySessionId[session.id].flatMap(SessionActuals.init)
                        if session.sessionType == .rest {
                            restRow(session, actuals: actuals)
                        } else {
                            sessionRow(session, actuals: actuals)
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
                        if week.weekNumber == 0 {
                            // The gap-filler week is always "now" — its
                            // title already says so, so the "THIS WEEK"
                            // badge below would just repeat it.
                            Text("This Week")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.brand.accent)
                        } else {
                            Text("Week \(week.weekNumber)")
                                .font(.subheadline.bold())
                                .foregroundStyle(isCurrent ? Color.brand.accent : Color.brand.textPrimary)
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
                    .foregroundStyle(isCurrent ? Color.brand.accent : Color.brand.textPrimary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(Color.brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(week.weekNumber == 0 ? "This week" : "Week \(week.weekNumber)"), \(week.phase.displayName), \(completedCount) of \(sessionCount) completed, \(Int(week.targetWeeklyKm)) kilometres")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
        .accessibilityAddTraits(isExpanded ? [.isHeader, .isSelected] : .isHeader)
    }

    // MARK: - Session row (active days)

    @ViewBuilder
    private func sessionRow(_ session: PlannedSession, actuals: SessionActuals?) -> some View {
        let isToday = todayDayOfWeek == session.dayOfWeek
        let isCompleted = actuals != nil
        let isSending: Bool = {
            guard case let .sending(id) = quickStartStatus else { return false }
            return id == session.id
        }()

        Button {
            onTap(session, isToday)
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
                    if let actuals {
                        Text("Actual: \(actuals.displayText(unit: paceUnit))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.brand.accent)
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
        .accessibilityLabel(accessibilityLabel(for: session, isToday: isToday, actuals: actuals))
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

    /// Usually a quiet line so the eye skips past it — but if training
    /// happened on a planned rest day (sync-back matched a `CompletedWorkout`
    /// to this session), surface that instead of staying silent about it.
    @ViewBuilder
    private func restRow(_ session: PlannedSession, actuals: SessionActuals?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: session.sessionType.symbolName)
                .font(.subheadline)
                .foregroundStyle(Color.brand.textSecondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(dayLabel(session.dayOfWeek)) · Rest")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.textSecondary)
                if let actuals {
                    Text("Logged: \(actuals.displayText(unit: paceUnit))")
                        .font(.caption.monospacedDigit())
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
        .padding(.vertical, 4)
        .padding(.horizontal, 14)
        .opacity(actuals == nil ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(restAccessibilityLabel(for: session, actuals: actuals))
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

    private func accessibilityLabel(for session: PlannedSession, isToday: Bool, actuals: SessionActuals?) -> String {
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
        if let actuals {
            parts.append("completed, actual \(actuals.displayText(unit: paceUnit))")
        }
        return parts.joined(separator: ", ")
    }

    private func restAccessibilityLabel(for session: PlannedSession, actuals: SessionActuals?) -> String {
        var label = "\(dayLabel(session.dayOfWeek)), rest day"
        if let actuals {
            label += ", but logged \(actuals.displayText(unit: paceUnit))"
        }
        return label
    }

    private func dayLabel(_ day: Int) -> String {
        weekdayLabel(day)
    }
}

// MARK: - Session actuals

/// "What actually happened" for a `PlannedSession`, derived from its matched
/// `CompletedWorkout` row(s). A session can have more than one match (a
/// same-day double-workout) — these are summed into one total rather than
/// shown as competing numbers, so the runner sees their combined effort for
/// the day alongside what was planned ("並陳顯示").
struct SessionActuals: Equatable {
    let distanceKm: Double
    let paceSecPerKm: Double

    init?(_ workouts: [CompletedWorkout]) {
        guard !workouts.isEmpty else { return nil }
        let totalDistanceKm = workouts.reduce(0) { $0 + $1.actualDistanceKm }
        let totalDurationSec = workouts.reduce(0) { $0 + $1.actualDurationSec }
        guard totalDistanceKm > 0 else { return nil }
        self.distanceKm = totalDistanceKm
        self.paceSecPerKm = totalDurationSec / totalDistanceKm
    }

    func displayText(unit: PaceUnit) -> String {
        "\(PaceFormatting.distance(metres: distanceKm * 1_000, unit: unit)) · \(PaceFormatting.pace(secondsPerKm: paceSecPerKm, unit: unit))"
    }
}

// MARK: - Weekday label helper

/// Locale-aware short weekday label for a schema day index (Mon=1 … Sun=7).
/// `Calendar.shortWeekdaySymbols` is Sunday-first, so `dayOfWeek % 7` maps
/// Mon=1→index 1 … Sat=6→index 6 and Sun=7→index 0. Replaces four
/// hardcoded English ["Mon"…] arrays that broke all non-English locales.
func weekdayLabel(_ dayOfWeek: Int) -> String {
    let symbols = Calendar.current.shortWeekdaySymbols
    let idx = dayOfWeek % 7
    guard symbols.indices.contains(idx) else { return "?" }
    return symbols[idx]
}
