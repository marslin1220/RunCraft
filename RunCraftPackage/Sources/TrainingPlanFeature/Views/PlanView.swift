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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let goal = activeGoal {
                        RaceCountdownRing(goal: goal)
                            .padding(.top, 16)

                        if let zones = store.paceZones {
                            PaceZonesSummaryCard(zones: zones)
                        }

                        if let currentWeek = currentWeek {
                            WeekSessionsSection(week: currentWeek)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training Paces")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                PaceChip(label: "E", pace: zones.easy.formatted(), color: Color(hex: "#4CAF50"))
                PaceChip(label: "M", pace: zones.marathon.formatted(), color: Color(hex: "#2196F3"))
                PaceChip(label: "T", pace: zones.threshold.formatted(), color: Color(hex: "#FFC107"))
                PaceChip(label: "I", pace: zones.interval.formatted(), color: Color(hex: "#FF5722"))
                PaceChip(label: "R", pace: zones.repetition.formatted(), color: Color(hex: "#F44336"))
            }
        }
        .padding()
        .background(Color(hex: "#1A1B2E"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
    @FetchAll(PlannedSession.none) var sessions: [PlannedSession]

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
                SessionCard(session: session, weekStart: week.startDate)
            }
        }
        .task(id: week.id) {
            _ = await withErrorReporting {
                try await $sessions.load(
                    PlannedSession
                        .where { $0.weekId.eq(week.id) }
                        .order(by: \.dayOfWeek)
                )
            }
        }
    }
}

private struct SessionCard: View {
    let session: PlannedSession
    let weekStart: Date

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
        }
        .padding(12)
        .background(Color(hex: "#1A1B2E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
