import ComposableArchitecture
import Foundation
import HealthKitClient
import RunCraftModels
import SQLiteData
import VDOTEngine

@Reducer public struct TrainingPlan {
    @ObservableState public struct State {
        public var hasGoal: Bool = false
        public var currentVDOT: Double = 0
        public var paceZones: PaceZones? = nil
        public var isLoadingVDOT: Bool = false
        public var recoveryAdvice: RecoveryAdvice? = nil
        public var lastRecoveryDismissAt: Date? = nil
        public var vdotUpgrade: VDOTUpgrade? = nil
        public var path = StackState<Path.State>()
        @Presents public var destination: Destination.State? = nil

        public init() {}
    }

    /// VDOT-improvement signal surfaced from HealthKit when a fresh race
    /// from the runner's history implies a higher VDOT than the plan was
    /// generated against.
    public struct VDOTUpgrade: Equatable {
        public let oldVDOT: Double
        public let newVDOT: Double
    }

    /// Recovery / readiness signal surfaced from HealthKit when the runner
    /// has a hard session scheduled today but HRV or sleep say otherwise.
    public enum RecoveryAdvice: Equatable {
        /// HRV-driven hint to swap today's high-intensity session for easy.
        case suggestDowngrade(reason: String)
    }

    @Reducer public enum Path {
        case weekSchedule(WeekSchedule)
    }

    @Reducer public enum Destination {
        case setupRaceGoal(SetupRaceGoal)
        case deleteConfirm(AlertState<DeleteAlertAction>)
    }

    public enum DeleteAlertAction: Equatable {
        case confirmDelete
    }

    public enum Action {
        case onAppear
        case createGoalButtonTapped
        case checkRaceGoalResponse(Result<Bool, any Error>)
        case fetchVDOTTapped
        case vdotFetchResponse(Result<Double, any Error>)
        case deletePlanRequested
        case recalculateVDOTRequested
        case planDeleted
        case countdownTapped
        case paceChipTapped(PaceZoneName)
        case sessionTapped(PlannedSession)
        case fetchRecoveryAdvice
        case recoveryAdviceLoaded(RecoveryAdvice?)
        case applyDowngradeTapped
        case dismissRecoveryAdvice
        case checkVDOTUpgrade
        case vdotUpgradeDetected(VDOTUpgrade?)
        case acceptVDOTUpgradeTapped
        case dismissVDOTUpgrade
        case syncBackWorkouts
        case syncBackCompleted
        case path(StackActionOf<Path>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)

        public enum Delegate {
            /// Parent (AppFeature) should switch to Workshop tab and open this workout.
            case openWorkoutInWorkshop(WorkoutTemplate, source: TemplateSource)
        }

        public enum TemplateSource: Equatable {
            case planSession
            case template
        }
    }

    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [database] send in
                    await send(.checkRaceGoalResponse(Result {
                        let count = try await database.read { db in
                            try RaceGoal.all.fetchCount(db)
                        }
                        return count > 0
                    }))
                }

            case .createGoalButtonTapped:
                state.destination = .setupRaceGoal(SetupRaceGoal.State())
                return .none

            case let .checkRaceGoalResponse(.success(hasGoal)):
                state.hasGoal = hasGoal
                if hasGoal {
                    return .send(.fetchVDOTTapped)
                }
                return .none

            case .checkRaceGoalResponse(.failure):
                state.hasGoal = false
                return .none

            case .fetchVDOTTapped:
                state.isLoadingVDOT = true
                return .run { [database] send in
                    await send(.vdotFetchResponse(Result {
                        let goal = try await database.read { db in
                            try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                        }
                        guard let goal else { throw PlanError.noGoalFound }
                        return goal.currentVDOT
                    }))
                }

            case let .vdotFetchResponse(.success(vdot)):
                state.isLoadingVDOT = false
                state.currentVDOT = vdot
                state.paceZones = VDOTCalculator.paceZones(vdot: vdot)
                // VDOT is loaded → kick the readiness, progress and
                // sync-back checks now that we know there's an active plan
                // with a today's session to evaluate and a baseline VDOT
                // to compare against.
                return .merge(
                    .send(.fetchRecoveryAdvice),
                    .send(.syncBackWorkouts),
                    .send(.checkVDOTUpgrade)
                )

            case .vdotFetchResponse(.failure):
                state.isLoadingVDOT = false
                return .none

            case .deletePlanRequested:
                state.destination = .deleteConfirm(AlertState {
                    TextState("Delete plan?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This removes your race goal and all generated weekly sessions. Completed workouts are kept.")
                })
                return .none

            case .recalculateVDOTRequested:
                state.destination = .setupRaceGoal(SetupRaceGoal.State())
                return .none

            case .destination(.presented(.deleteConfirm(.confirmDelete))):
                return .run { [database] send in
                    try await database.write { db in
                        // FK cascades remove trainingWeeks and plannedSessions automatically
                        try RaceGoal.all.delete().execute(db)
                    }
                    await send(.planDeleted)
                }

            case .planDeleted:
                state.hasGoal = false
                state.paceZones = nil
                return .none

            case .countdownTapped:
                state.path.append(.weekSchedule(WeekSchedule.State()))
                return .none

            case .fetchRecoveryAdvice:
                // Debounce: if the user dismissed within the last 6 h, don't
                // re-evaluate. They'll see the next banner after that window
                // or when the app is relaunched (state is in-memory).
                if let last = state.lastRecoveryDismissAt,
                   now.timeIntervalSince(last) < 6 * 3600 {
                    return .none
                }
                return .run { [database, healthKitClient] send in
                    // 1. Find today's planned session.
                    let weekday = Calendar.current.component(.weekday, from: Date())
                    let dayOfWeek = weekday == 1 ? 7 : weekday - 1  // Sun=1 → 7
                    let todaysType = try? await database.read { db -> SessionType? in
                        try PlannedSession
                            .where { $0.dayOfWeek.eq(dayOfWeek) }
                            .fetchOne(db)?.sessionType
                    }
                    // 2. Only consider downgrading hard sessions.
                    let hardTypes: Set<SessionType> = [.interval, .tempo, .repetition]
                    guard let todaysType = todaysType, hardTypes.contains(todaysType) else {
                        await send(.recoveryAdviceLoaded(nil))
                        return
                    }
                    // 3. Check HRV + sleep.
                    let hrv = (try? await healthKitClient.latestHRV()) ?? nil
                    let sleepHours = (try? await healthKitClient.recentSleepHours(1)) ?? 0
                    var reasons: [String] = []
                    if let hrv, hrv < 30 {
                        reasons.append("HRV low (\(Int(hrv.rounded())) ms)")
                    }
                    if sleepHours > 0 && sleepHours < 6 {
                        let sleepStr = sleepHours.formatted(.number.precision(.fractionLength(0...1)))
                        reasons.append("only \(sleepStr) h sleep")
                    }
                    let advice: RecoveryAdvice? = reasons.isEmpty
                        ? nil
                        : .suggestDowngrade(reason: reasons.joined(separator: " · "))
                    await send(.recoveryAdviceLoaded(advice))
                }

            case let .recoveryAdviceLoaded(advice):
                state.recoveryAdvice = advice
                return .none

            case .applyDowngradeTapped:
                state.recoveryAdvice = nil
                return .run { [database] _ in
                    try await database.write { db in
                        let weeks = try TrainingWeek.all.fetchAll(db)
                        guard let currentWeek = TrainingWeek.current(in: weeks) else { return }
                        let weekday = Calendar.current.component(.weekday, from: Date())
                        let dayOfWeek = weekday == 1 ? 7 : weekday - 1
                        try PlannedSession
                            .where { $0.weekId.eq(currentWeek.id) }
                            .where { $0.dayOfWeek.eq(dayOfWeek) }
                            .update {
                                $0.sessionType = #bind(.easy)
                                $0.targetPaceZone = #bind(.easy)
                                $0.targetDistanceKm = #bind(5)
                                $0.notes = #bind("Auto-downgraded for recovery")
                            }
                            .execute(db)
                    }
                }

            case .dismissRecoveryAdvice:
                state.recoveryAdvice = nil
                state.lastRecoveryDismissAt = now
                return .none

            case .checkVDOTUpgrade:
                let currentVDOT = state.currentVDOT
                guard currentVDOT > 0 else { return .none }
                return .run { [database, healthKitClient] send in
                    // Signal A: a fresh race time from HealthKit implies a
                    // higher VDOT than the plan was generated against.
                    var detectedBest: Double = 0
                    for distance in [RaceDistanceQuery.fiveK, .tenK, .halfMarathon] {
                        if let time = try? await healthKitClient.bestRaceTime(distance) {
                            let v = VDOTCalculator.vdot(distanceMeters: distance.metres, timeSeconds: time)
                            detectedBest = max(detectedBest, v)
                        }
                    }
                    var suggested: Double? = nil
                    if detectedBest >= currentVDOT + 1 {
                        suggested = detectedBest
                    }

                    // Signal B: the runner consistently beat target pace on
                    // recent hard sessions (interval / tempo / repetition).
                    let consecutiveOverperformance = try? await database.read { db -> Int in
                        let hardTypes: [SessionType] = [.interval, .tempo, .repetition]
                        let sessions = try PlannedSession.all.fetchAll(db)
                        let hardSessionIds = Set(
                            sessions.filter { hardTypes.contains($0.sessionType) }.map(\.id)
                        )
                        let recent = try CompletedWorkout
                            .order { $0.completedAt.desc() }
                            .fetchAll(db)
                            .prefix(10)
                        var streak = 0
                        for row in recent {
                            guard let planId = row.plannedSessionId,
                                  hardSessionIds.contains(planId)
                            else { continue }
                            if row.paceAchievementRatio < 0.95 {
                                streak += 1
                            } else {
                                break
                            }
                        }
                        return streak
                    }
                    if (consecutiveOverperformance ?? 0) >= 2,
                       (suggested ?? 0) < currentVDOT + 1 {
                        suggested = currentVDOT + 1
                    }

                    guard let suggested else {
                        await send(.vdotUpgradeDetected(nil))
                        return
                    }
                    await send(.vdotUpgradeDetected(.init(
                        oldVDOT: currentVDOT,
                        newVDOT: suggested
                    )))
                }

            case let .vdotUpgradeDetected(upgrade):
                state.vdotUpgrade = upgrade
                return .none

            case .acceptVDOTUpgradeTapped:
                guard let upgrade = state.vdotUpgrade else { return .none }
                let newVDOT = upgrade.newVDOT
                state.vdotUpgrade = nil
                state.currentVDOT = newVDOT
                state.paceZones = VDOTCalculator.paceZones(vdot: newVDOT)
                return .run { [database] _ in
                    try await database.write { db in
                        try RaceGoal.update {
                            $0.currentVDOT = newVDOT
                        }.execute(db)
                    }
                }

            case .dismissVDOTUpgrade:
                state.vdotUpgrade = nil
                return .none

            case .syncBackWorkouts:
                let vdot = state.currentVDOT
                return .run { [database, healthKitClient] send in
                    // Look back 90 days. Workouts older than that are unlikely
                    // to map to a current 16-week plan and aren't worth the
                    // round-trip.
                    let lookback = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
                    let observations = (try? await healthKitClient.recentWorkouts(lookback)) ?? []
                    guard !observations.isEmpty else {
                        await send(.syncBackCompleted)
                        return
                    }
                    try await database.write { db in
                        let weeks = try TrainingWeek.all.fetchAll(db)
                        let sessions = try PlannedSession.all.fetchAll(db)
                        let alreadyImported = Set(
                            try CompletedWorkout.all
                                .fetchAll(db)
                                .compactMap(\.hkWorkoutId)
                        )
                        for obs in observations where !alreadyImported.contains(obs.id) {
                            let observation = WorkoutObservation(
                                id: obs.id,
                                startDate: obs.startDate,
                                duration: obs.duration,
                                distanceMeters: obs.distanceMeters
                            )
                            if let row = WorkoutSyncBack.makeCompletedWorkout(
                                from: observation,
                                weeks: weeks,
                                sessions: sessions,
                                currentVDOT: vdot
                            ) {
                                try CompletedWorkout.insert { row }.execute(db)
                            }
                        }
                    }
                    await send(.syncBackCompleted)
                }

            case .syncBackCompleted:
                // After the sync wrote any new rows, re-check whether the
                // runner has been consistently faster than target on hard
                // sessions — that's the second VDOT-upgrade signal alongside
                // the historic best race-time check.
                return .send(.checkVDOTUpgrade)

            case let .paceChipTapped(zone):
                let template = makePaceFocusTemplate(zone: zone, vdot: state.currentVDOT)
                return .send(.delegate(.openWorkoutInWorkshop(template, source: .template)))

            case let .sessionTapped(session):
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)
                return .send(.delegate(.openWorkoutInWorkshop(template, source: .planSession)))

            case let .path(.element(_, .weekSchedule(.delegate(.openSession(session))))):
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)
                state.path.removeAll()
                return .send(.delegate(.openWorkoutInWorkshop(template, source: .planSession)))

            case .path:
                return .none

            case .delegate:
                return .none

            case .destination(.dismiss):
                // Destination closed (e.g. SetupRaceGoal sheet dismissed after Save).
                // Re-check goal/VDOT state so paceZones refresh immediately.
                return .send(.onAppear)

            case .destination:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
    }

    /// Quick-action template: 30-minute run at the chosen pace zone.
    private func makePaceFocusTemplate(zone: PaceZoneName, vdot: Double) -> WorkoutTemplate {
        let step = WorkoutStep(
            kind: zone == .easy ? .work : .work,
            goal: .time(seconds: 30 * 60),
            alert: .paceZone(zone, vdot: vdot)
        )
        return WorkoutTemplate(
            name: "\(zone.displayName) Run · 30 min",
            blocks: [.step(step)]
        )
    }
}

// MARK: - Week schedule sub-feature

@Reducer public struct WeekSchedule {
    @ObservableState public struct State: Equatable {
        public init() {}
    }
    public enum Action {
        case sessionTapped(PlannedSession)
        case delegate(Delegate)
        public enum Delegate {
            case openSession(PlannedSession)
        }
    }
    public init() {}
    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case let .sessionTapped(s):
                return .send(.delegate(.openSession(s)))
            case .delegate:
                return .none
            }
        }
    }
}

public enum PlanError: Error {
    case noGoalFound
}
