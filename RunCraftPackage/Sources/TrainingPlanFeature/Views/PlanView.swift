import ComposableArchitecture
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

                        if let zones = store.paceZones {
                            PaceZonesSummaryCard(zones: zones) { zone in
                                store.send(.paceChipTapped(zone))
                            }
                        }

                        if let currentWeek = currentWeek {
                            WeekSessionsSection(week: currentWeek) { session in
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
                                .foregroundStyle(Color(hex: "#CCFF00"))
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
        let today = Date()
        return allWeeks.first { week in
            guard let nextMonday = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: week.startDate) else {
                return false
            }
            return week.startDate <= today && today < nextMonday
        }
    }
}

// MARK: - Subviews

private struct RaceCountdownRing: View {
    let goal: RaceGoal

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        Color(hex: "#CCFF00"),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: ringProgress)

                VStack(spacing: 2) {
                    Text("\(max(goal.daysUntilRace, 0))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(goal.name)
                .font(.headline)
                .foregroundStyle(.white)

            Text(goal.targetDate, format: .dateTime.day().month().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("tap to build")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                tappableChip(.easy,       zones.easy,       color: Color(hex: "#4CAF50"))
                tappableChip(.marathon,   zones.marathon,   color: Color(hex: "#2196F3"))
                tappableChip(.threshold,  zones.threshold,  color: Color(hex: "#FFC107"))
                tappableChip(.interval,   zones.interval,   color: Color(hex: "#FF5722"))
                tappableChip(.repetition, zones.repetition, color: Color(hex: "#F44336"))
            }
        }
        .padding()
        .background(Color(hex: "#1A1B2E"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tappableChip(_ zone: PaceZoneName, _ range: PaceZones.PaceRange, color: Color) -> some View {
        Button {
            onTap(zone)
        } label: {
            PaceChip(label: zone.letter, pace: range.formatted(), color: color)
        }
        .buttonStyle(.plain)
    }
}

private struct PaceChip: View {
    let label: String
    let pace: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(pace.components(separatedBy: " ").first ?? pace)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WeekSessionsSection: View {
    let week: TrainingWeek
    let onSessionTap: (PlannedSession) -> Void
    @FetchAll(PlannedSession.none) var sessions: [PlannedSession]
    @FetchAll(CompletedWorkout.none) var completedThisWeek: [CompletedWorkout]

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
                    .foregroundStyle(Color(hex: "#CCFF00"))
            }

            ForEach(sessions) { session in
                Button {
                    onSessionTap(session)
                } label: {
                    SessionCard(
                        session: session,
                        weekStart: week.startDate,
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
        _ = await withErrorReporting {
            try await $completedThisWeek.load(CompletedWorkout.all)
        }
    }
}

private struct SessionCard: View {
    let session: PlannedSession
    let weekStart: Date
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: session.sessionType.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(dayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(session.sessionType.displayName)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)

                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let km = session.targetDistanceKm {
                Text("\(km, format: .number.precision(.fractionLength(0))) km")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let min = session.targetDurationMin {
                Text("\(min) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: "#4CAF50"))
            }
        }
        .padding(12)
        .background(Color(hex: "#1A1B2E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isCompleted ? 0.7 : 1.0)
    }

    private var dayLabel: String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let idx = session.dayOfWeek - 1
        guard idx >= 0, idx < days.count else { return "" }
        return days[idx]
    }
}

private struct EmptyPlanPrompt: View {
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "#CCFF00"))

            Text("No race goal yet")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)

            Text("Create your first race goal and we'll build a personalised 16-week training plan.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(action: onCreateTapped) {
                Text("Create Race Goal")
                    .bold()
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#CCFF00"))
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Hex Color Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Week Schedule View (full 16-week timeline)

struct WeekScheduleView: View {
    let store: StoreOf<WeekSchedule>
    let allWeeks: [TrainingWeek]
    @FetchAll(PlannedSession.none) var allSessions: [PlannedSession]
    @FetchAll(CompletedWorkout.none) var completedAll: [CompletedWorkout]

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
        .task { await loadAllData() }
    }

    private func isCurrentWeek(_ week: TrainingWeek) -> Bool {
        let today = Date()
        guard let next = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: week.startDate) else {
            return false
        }
        return week.startDate <= today && today < next
    }

    private func loadAllData() async {
        _ = await withErrorReporting {
            try await $allSessions.load(PlannedSession.all)
        }
        _ = await withErrorReporting {
            try await $completedAll.load(CompletedWorkout.all)
        }
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
                    .foregroundStyle(isCurrent ? Color(hex: "#CCFF00") : .white)
                if isCurrent {
                    Text("THIS WEEK")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#CCFF00").opacity(0.2))
                        .foregroundStyle(Color(hex: "#CCFF00"))
                        .clipShape(Capsule())
                }
                Spacer()
                Text("\(week.targetWeeklyKm, format: .number.precision(.fractionLength(0))) km")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        Spacer()
                        if let km = session.targetDistanceKm {
                            Text("\(km, format: .number.precision(.fractionLength(0...1))) km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if completedIds.contains(session.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#4CAF50"))
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "#1A1B2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
