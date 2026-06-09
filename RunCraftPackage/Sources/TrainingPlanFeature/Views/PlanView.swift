import ComposableArchitecture
import DesignSystem
import IssueReporting
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine

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
                    allWeeks: allWeeks
                )
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
            .accessibilityLabel("\(max(goal.daysUntilRace, 0)) days until \(goal.name)")

            Text(goal.name)
                .font(.headline)
                .foregroundStyle(.white)

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
    let store: StoreOf<WeekSchedule>
    let allWeeks: [TrainingWeek]
    @FetchAll var allSessions: [PlannedSession]
    @FetchAll var completedAll: [CompletedWorkout]

    private var completedSessionIds: Set<UUID> {
        Set(completedAll.compactMap(\.plannedSessionId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(allWeeks) { week in
                    WeekSection(
                        week: week,
                        sessions: allSessions.filter { $0.weekId == week.id }
                                             .sorted { $0.dayOfWeek < $1.dayOfWeek },
                        completedIds: completedSessionIds,
                        isCurrent: isCurrentWeek(week),
                        onTap: { session in store.send(.sessionTapped(session)) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .background(Color.black)
        .navigationTitle("Full Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func isCurrentWeek(_ week: TrainingWeek) -> Bool {
        TrainingWeek.current(in: [week]) != nil
    }
}

private struct WeekSection: View {
    let week: TrainingWeek
    let sessions: [PlannedSession]
    let completedIds: Set<UUID>
    let isCurrent: Bool
    let onTap: (PlannedSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week \(week.weekNumber) · \(week.phase.displayName)")
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
                Spacer()
                Text("\(week.targetWeeklyKm, format: .number.precision(.fractionLength(0))) km")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
            }

            ForEach(sessions) { session in
                Button {
                    onTap(session)
                } label: {
                    HStack(spacing: 12) {
                        Text(dayLabel(session.dayOfWeek))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Color(hex: session.sessionType.colorHex))
                            .frame(width: 32)
                        Text(session.sessionType.displayName)
                            .font(.caption)
                            .foregroundStyle(.white)
                        // Zone letter — the structural intent. Specific
                        // pace numbers are only honest for the current
                        // week (and computed at runtime there), so
                        // future weeks just show the zone badge.
                        if let zone = session.targetPaceZone {
                            Text(zone.letter)
                                .font(.caption2.bold())
                                .foregroundStyle(Color.brand.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        Spacer()
                        if let km = session.targetDistanceKm {
                            Text("\(km, format: .number.precision(.fractionLength(0...1))) km")
                                .font(.caption)
                                .foregroundStyle(Color.brand.textSecondary)
                        }
                        if completedIds.contains(session.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.brand.success)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Color.brand.textSecondary)
                        }
                    }
                    .padding(10)
                    .background(Color.brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(isCurrent ? 1.0 : 0.85)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayLabel(_ day: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = day - 1
        return (idx >= 0 && idx < days.count) ? days[idx] : "?"
    }
}
