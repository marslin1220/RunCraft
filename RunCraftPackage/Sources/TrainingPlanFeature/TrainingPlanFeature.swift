import AppleWatchSync
import ComposableArchitecture
import Foundation
import HealthKitClient
import RunCraftModels
import SQLiteData
import VDOTEngine
import WorkshopFeature

@Reducer public struct TrainingPlan {
    @ObservableState public struct State {
        public var currentVDOT: Double = 0
        public var paceZones: PaceZones? = nil
        public var recoveryAdvice: RecoveryAdvice? = nil
        public var vdotUpgrade: VDOTUpgrade? = nil
        /// Set when HealthKit reads have succeeded before (a synced
        /// `CompletedWorkout` exists) but read authorization now reports
        /// `.needsRequest` — i.e. the runner revoked Health permission in
        /// iOS Settings after granting it.
        public var healthPermissionLost: Bool = false
        public var path = StackState<Path.State>()
        @Presents public var destination: Destination.State? = nil
        /// Id of the session currently being pushed to the Watch via the
        /// today-row play button. Drives the ProgressView in the card so
        /// the runner sees their tap registered.
        public var watchAvailable: Bool = true
        public var quickStartSendingSessionId: UUID? = nil
        @Presents public var quickStartAlert: AlertState<Action.QuickStartAlert>? = nil

        /// Time the user last dismissed the recovery banner. Persisted so
        /// dismissals survive app restarts; `.distantPast` = never dismissed.
        /// Key uses `_` not `.` because UserDefaults KVO can't observe dots.
        @Shared(.appStorage("recoveryBanner_lastDismissAt"))
        public var recoveryBannerLastDismissAt = Date.distantPast
        /// Same idea for the VDOT-upgrade banner.
        @Shared(.appStorage("vdotUpgrade_lastDismissAt"))
        public var vdotUpgradeLastDismissAt = Date.distantPast
        /// Same idea for the Health-permission-lost banner.
        @Shared(.appStorage("healthPermissionBanner_lastDismissAt"))
        public var healthPermissionBannerLastDismissAt = Date.distantPast

        public init() {}
    }

    /// How long a dismissal silences either banner before it can re-appear.
    /// Six hours matches a typical training rhythm: dismissed in the morning,
    /// the banner can return that evening or next day if signals still apply.
    private static let bannerDebounce: TimeInterval = 6 * 3600

    /// Whether `.needsRequest` should be surfaced as "permission lost".
    ///
    /// iOS never reports HealthKit read-authorization status directly — both
    /// "never granted" and "revoked via Settings" make
    /// `getRequestStatusForAuthorization` return `.shouldRequest`
    /// (`.needsRequest`). We only treat that as alarming if HealthKit reads
    /// have succeeded before (a `CompletedWorkout` with a non-nil
    /// `hkWorkoutId` exists) — otherwise permission was simply never
    /// granted, which is normal and not worth alarming the runner about.
    static func healthPermissionLost(hasSyncedBefore: Bool, status: HealthAuthorizationRequestStatus) -> Bool {
        hasSyncedBefore && status == .needsRequest
    }

    /// VDOT-improvement signal surfaced from HealthKit when a fresh race
    /// from the runner's history implies a higher VDOT than the plan was
    /// generated against.
    public struct VDOTUpgrade: Equatable {
        public let oldVDOT: Double
        public let newVDOT: Double
        public let source: VDOTSnapshot.Source
    }

    /// Recovery / readiness signal surfaced from HealthKit when the runner
    /// has a hard session scheduled today but HRV or sleep say otherwise.
    public enum RecoveryAdvice: Equatable {
        /// HRV-driven hint to swap today's high-intensity session for easy.
        case suggestDowngrade(reason: String)
    }

    @Reducer public enum Path {
        case weekSchedule(WeekSchedule)
        /// Pushed onto Plan's own stack when the user opens a workout from
        /// Full Schedule, so Back lands them back on the schedule rather
        /// than bouncing to the Workshop tab they didn't visit.
        case editor(WorkoutEditor)
    }

    @Reducer public enum Destination {
        case setupRaceGoal(SetupRaceGoal)
        case setupVDOT(SetupVDOT)
        case adjustVDOT(AdjustVDOT)
        case adjustTrainingDays(AdjustTrainingDays)
        case deleteConfirm(AlertState<DeleteAlertAction>)
    }

    public enum DeleteAlertAction: Equatable {
        case confirmDelete
    }

    public enum Action {
        case onAppear
        case activeGoalLoaded(Result<RaceGoal?, any Error>)
        /// Re-anchors the placeholder ("Base Training") rolling week to the
        /// current calendar week once the previous one has rolled past.
        case refreshRollingWeekIfNeeded(RaceGoal)
        case setupVDOTButtonTapped
        case addRaceGoalButtonTapped
        case addRaceGoalLoaded(RaceGoal?)
        case deletePlanRequested(isPlaceholder: Bool)
        case recalculateVDOTRequested
        case adjustVDOTRequested
        case adjustTrainingDaysRequested(RaceGoal)
        case adjustTrainingDaysFromSettings
        case editGoalLoaded(RaceGoal?)
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
        case checkHealthAuthorization
        case healthAuthorizationChecked(lost: Bool)
        case dismissHealthPermissionBanner
        case requestHealthAuthorization
        case syncBackWorkouts
        case syncBackCompleted
        case watchScheduleSync
        /// Sent from the Plan tab's today-card "play" button. Bypasses
        /// the editor and pushes the workout straight to Apple Watch.
        case quickStartSession(PlannedSession)
        case quickStartResponse(sessionId: UUID, Result<Void, any Error>)
        case quickStartAlert(PresentationAction<QuickStartAlert>)
        /// Substitute a planned session with an alternative type and optional
        /// variant note. Writes straight to the DB and re-syncs the Watch schedule.
        case swapSession(PlannedSession, to: SessionType, variantNote: String?)
        case path(StackActionOf<Path>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)

        public enum QuickStartAlert: Equatable {}

        public enum Delegate {
            /// Parent (AppFeature) should switch to Workshop tab and open this workout.
            /// `isTodaySession` is forwarded to `WorkoutEditor.State` — see
            /// `WorkoutEditor.State.isTodaySession`.
            case openWorkoutInWorkshop(WorkoutTemplate, source: TemplateSource, isTodaySession: Bool)
        }

        public enum TemplateSource: Equatable {
            case planSession
            case template
        }
    }

    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date.now) var now
    @Dependency(\.workoutTemplateRepository) var repository
    @Dependency(\.watchConnectivityClient) var watchConnectivityClient
    @Dependency(\.hkWatchTriggerClient) var hkWatchTriggerClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.watchAvailable = watchConnectivityClient.isWatchPaired()
                return .run { [database] send in
                    await send(.activeGoalLoaded(Result {
                        try await database.read { db in
                            try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                        }
                    }))
                }

            case let .activeGoalLoaded(.success(.some(goal))):
                state.currentVDOT = goal.currentVDOT
                state.paceZones = VDOTCalculator.paceZones(vdot: goal.currentVDOT)
                // VDOT is loaded → kick the readiness, progress and
                // sync-back checks now that we know there's an active plan
                // with a today's session to evaluate and a baseline VDOT
                // to compare against.
                return .merge(
                    .send(.fetchRecoveryAdvice),
                    .send(.syncBackWorkouts),
                    .send(.checkVDOTUpgrade),
                    .send(.checkHealthAuthorization),
                    .send(.refreshRollingWeekIfNeeded(goal)),
                    .send(.watchScheduleSync)
                )

            case .activeGoalLoaded(.success(nil)):
                state.currentVDOT = 0
                state.paceZones = nil
                return .none

            case .activeGoalLoaded(.failure):
                state.currentVDOT = 0
                state.paceZones = nil
                return .none

            case let .refreshRollingWeekIfNeeded(goal):
                return .run { [database] _ in
                    try await database.write { db in
                        let weeks = try TrainingWeek
                            .where { $0.raceGoalId.eq(goal.id) }
                            .fetchAll(db)

                        func hasSessions(forWeekId weekId: UUID) throws -> Bool {
                            try PlannedSession.where { $0.weekId.eq(weekId) }.fetchCount(db) > 0
                        }

                        if goal.isPlaceholder {
                            // State B: the placeholder goal's only week is
                            // this rolling "Base Training" week. Regenerate
                            // it whenever it's rolled past the current week,
                            // or if it's missing its planned sessions.
                            if let current = TrainingWeek.current(in: weeks),
                               try hasSessions(forWeekId: current.id) {
                                // Check whether any completed workouts are
                                // linked to this week's sessions. If so,
                                // only patch weekNumber to avoid breaking FK
                                // links; otherwise regenerate with the
                                // corrected scheduling algorithm.
                                let currentSessionIds = Set(
                                    try PlannedSession
                                        .where { $0.weekId.eq(current.id) }
                                        .fetchAll(db)
                                        .map(\.id)
                                )
                                let hasCompletions = try CompletedWorkout.all
                                    .fetchAll(db)
                                    .contains {
                                        $0.plannedSessionId.map { currentSessionIds.contains($0) } ?? false
                                    }
                                if hasCompletions {
                                    if current.weekNumber != 0 {
                                        var fixed = current
                                        fixed.weekNumber = 0
                                        try TrainingWeek.upsert { fixed }.execute(db)
                                    }
                                    return
                                }
                                // No completions — fall through to delete + regenerate below.
                            }
                            try TrainingWeek
                                .where { $0.raceGoalId.eq(goal.id) }
                                .delete()
                                .execute(db)
                            let (week, newSessions) = TrainingPlanGenerator.rollingWeek(
                                raceGoalId: goal.id, vdot: goal.currentVDOT, weekNumber: 0,
                                availableDays: goal.availableDays, longRunDay: goal.longRunDay
                            )
                            try TrainingWeek.upsert { week }.execute(db)
                            for session in newSessions {
                                try PlannedSession.upsert { session }.execute(db)
                            }
                            return
                        }

                        // State C: weeks 1...16 are the periodized plan and
                        // are never touched here. `weekNumber == 0` is a
                        // gap-filler rolling week shown only while "today"
                        // falls before the plan's week 1 — keep it in sync
                        // without disturbing the real plan.
                        let planWeeks = weeks.filter { $0.weekNumber >= 1 }
                        let gapWeek = weeks.first { $0.weekNumber == 0 }

                        if TrainingWeek.current(in: planWeeks) != nil {
                            if gapWeek != nil {
                                try TrainingWeek
                                    .where { $0.raceGoalId.eq(goal.id) }
                                    .where { $0.weekNumber.eq(0) }
                                    .delete()
                                    .execute(db)
                            }
                            return
                        }

                        if let gapWeek,
                           TrainingWeek.current(in: [gapWeek]) != nil,
                           try hasSessions(forWeekId: gapWeek.id) {
                            return
                        }

                        if gapWeek != nil {
                            try TrainingWeek
                                .where { $0.raceGoalId.eq(goal.id) }
                                .where { $0.weekNumber.eq(0) }
                                .delete()
                                .execute(db)
                        }
                        let (week, sessions) = TrainingPlanGenerator.rollingWeek(
                            raceGoalId: goal.id, vdot: goal.currentVDOT, weekNumber: 0,
                            availableDays: goal.availableDays, longRunDay: goal.longRunDay
                        )
                        try TrainingWeek.upsert { week }.execute(db)
                        for session in sessions {
                            try PlannedSession.upsert { session }.execute(db)
                        }
                    }
                }

            case .setupVDOTButtonTapped:
                state.destination = .setupVDOT(SetupVDOT.State())
                return .none

            case .addRaceGoalButtonTapped:
                return .run { [database] send in
                    let goal = try? await database.read { db in
                        try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                    }
                    await send(.addRaceGoalLoaded(goal))
                }

            case let .addRaceGoalLoaded(goal):
                if let goal, goal.isPlaceholder {
                    state.destination = .setupRaceGoal(SetupRaceGoal.State(convertingPlaceholder: goal))
                } else {
                    state.destination = .setupRaceGoal(SetupRaceGoal.State())
                }
                return .none

            case let .deletePlanRequested(isPlaceholder):
                state.destination = .deleteConfirm(AlertState {
                    TextState(isPlaceholder ? "Remove VDOT setup?" : "Delete plan?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState(isPlaceholder ? "Remove" : "Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState(
                        isPlaceholder
                            ? "This removes your base training week. Completed workouts are kept."
                            : "This removes your race goal and all generated weekly sessions. Completed workouts are kept."
                    )
                })
                return .none

            case .recalculateVDOTRequested:
                return .run { [database] send in
                    let goal = try? await database.read { db in
                        try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                    }
                    await send(.editGoalLoaded(goal))
                }

            case let .editGoalLoaded(goal):
                if let goal {
                    state.destination = .setupRaceGoal(SetupRaceGoal.State(editing: goal))
                } else {
                    state.destination = .setupRaceGoal(SetupRaceGoal.State())
                }
                return .none

            case .adjustVDOTRequested:
                state.destination = .adjustVDOT(AdjustVDOT.State(currentVDOT: state.currentVDOT))
                return .none

            case let .adjustTrainingDaysRequested(goal):
                state.destination = .adjustTrainingDays(AdjustTrainingDays.State(goal: goal))
                return .none

            case .adjustTrainingDaysFromSettings:
                return .run { [database] send in
                    let goal = try? await database.read { db in
                        try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                    }
                    if let goal {
                        await send(.adjustTrainingDaysRequested(goal))
                    }
                }

            case .destination(.presented(.deleteConfirm(.confirmDelete))):
                return .run { [database] send in
                    try await database.write { db in
                        // FK cascades remove trainingWeeks and plannedSessions automatically
                        try RaceGoal.all.delete().execute(db)
                    }
                    await send(.planDeleted)
                }

            case .planDeleted:
                state.currentVDOT = 0
                state.paceZones = nil
                return .none

            case .countdownTapped:
                state.path.append(.weekSchedule(WeekSchedule.State(watchAvailable: state.watchAvailable)))
                return .none

            case .fetchRecoveryAdvice:
                // Debounce: if the user dismissed within the last 6 h, don't
                // re-evaluate. Timestamp is persisted to AppStorage so
                // dismissals survive app restarts.
                if now.timeIntervalSince(state.recoveryBannerLastDismissAt) < Self.bannerDebounce {
                    return .none
                }
                return .run { [database, healthKitClient] send in
                    // 1. Find today's planned session.
                    let dayOfWeek = PlannedSession.dayOfWeek(for: Date())
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
                return .merge(
                    .run { [database] _ in
                        try await database.write { db in
                            let weeks = try TrainingWeek.all.fetchAll(db)
                            guard let currentWeek = TrainingWeek.current(in: weeks) else { return }
                            let dayOfWeek = PlannedSession.dayOfWeek(for: Date())
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
                    },
                    .send(.watchScheduleSync)
                )

            case .dismissRecoveryAdvice:
                state.recoveryAdvice = nil
                state.$recoveryBannerLastDismissAt.withLock { $0 = now }
                return .none

            case .checkVDOTUpgrade:
                let currentVDOT = state.currentVDOT
                guard currentVDOT > 0 else { return .none }
                // Debounce: same 6 h window as the recovery banner. Skip the
                // HealthKit + DB round-trip if the user recently dismissed.
                if now.timeIntervalSince(state.vdotUpgradeLastDismissAt) < Self.bannerDebounce {
                    return .none
                }
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
                    var suggestedSource: VDOTSnapshot.Source = .raceTime
                    if detectedBest >= currentVDOT + 1 {
                        suggested = detectedBest
                        suggestedSource = .raceTime
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
                        suggestedSource = .overperformance
                    }

                    guard let suggested else {
                        await send(.vdotUpgradeDetected(nil))
                        return
                    }
                    await send(.vdotUpgradeDetected(.init(
                        oldVDOT: currentVDOT,
                        newVDOT: suggested,
                        source: suggestedSource
                    )))
                }

            case let .vdotUpgradeDetected(upgrade):
                state.vdotUpgrade = upgrade
                return .none

            case .acceptVDOTUpgradeTapped:
                guard let upgrade = state.vdotUpgrade else { return .none }
                let newVDOT = upgrade.newVDOT
                let source = upgrade.source
                state.vdotUpgrade = nil
                state.currentVDOT = newVDOT
                state.paceZones = VDOTCalculator.paceZones(vdot: newVDOT)
                return .merge(
                    .run { [database] _ in
                        try await database.write { db in
                            try RaceGoal.update {
                                $0.currentVDOT = newVDOT
                            }.execute(db)
                            let snapshot = VDOTSnapshot(vdot: newVDOT, source: source)
                            try VDOTSnapshot.upsert { snapshot }.execute(db)
                        }
                    },
                    .send(.watchScheduleSync)
                )

            case .dismissVDOTUpgrade:
                state.vdotUpgrade = nil
                state.$vdotUpgradeLastDismissAt.withLock { $0 = now }
                return .none

            case .checkHealthAuthorization:
                // Debounce: same 6 h window as the other banners.
                if now.timeIntervalSince(state.healthPermissionBannerLastDismissAt) < Self.bannerDebounce {
                    return .none
                }
                return .run { [database, healthKitClient] send in
                    let hasSyncedBefore = (try? await database.read { db in
                        try CompletedWorkout.all.fetchAll(db).contains { $0.hkWorkoutId != nil }
                    }) ?? false
                    // Skip the HealthKit round-trip entirely if reads have
                    // never succeeded — `.needsRequest` in that case just
                    // means permission was never granted, not lost.
                    guard hasSyncedBefore else {
                        await send(.healthAuthorizationChecked(lost: false))
                        return
                    }
                    let status = await healthKitClient.authorizationRequestStatus()
                    await send(.healthAuthorizationChecked(lost: Self.healthPermissionLost(hasSyncedBefore: hasSyncedBefore, status: status)))
                }

            case let .healthAuthorizationChecked(lost):
                state.healthPermissionLost = lost
                return .none

            case .dismissHealthPermissionBanner:
                state.healthPermissionLost = false
                state.$healthPermissionBannerLastDismissAt.withLock { $0 = now }
                return .none

            case .requestHealthAuthorization:
                return .run { [healthKitClient] send in
                    try? await healthKitClient.requestAuthorization()
                    await send(.checkHealthAuthorization)
                }

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

            case .watchScheduleSync:
                guard state.currentVDOT > 0 else { return .none }
                let vdot = state.currentVDOT
                return .run { [database, watchConnectivityClient] _ in
                    let schedPayload: WatchSchedulePayload? = try? await database.read { db in
                        let allWeeks = try TrainingWeek.all.fetchAll(db)
                        guard let currentWeek = TrainingWeek.current(in: allWeeks) else { return nil }
                        let sessions = try PlannedSession
                            .where { $0.weekId.eq(currentWeek.id) }
                            .fetchAll(db)
                        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                        let watchSessions = sessions
                            .filter { $0.sessionType != .rest }
                            .sorted { $0.dayOfWeek < $1.dayOfWeek }
                            .map { s in
                                let template = PlanSessionAdapter.makeTemplate(from: s, vdot: vdot)
                                return WatchSchedulePayload.Session(
                                    id: s.id,
                                    dayName: dayNames[max(0, min(s.dayOfWeek - 1, 6))],
                                    title: s.sessionType.displayName,
                                    sessionType: s.sessionType,
                                    dayOfWeek: s.dayOfWeek,
                                    payload: WatchWorkoutPayload(name: template.name, blocks: template.blocks)
                                )
                            }
                        let paceZones = VDOTCalculator.paceZones(vdot: vdot)
                        let unit = PaceUnit.current
                        let paceTemplates = PaceZoneName.allCases.map { zone -> WatchWorkoutPayload in
                            let step = WorkoutStep(
                                kind: .work,
                                goal: .time(seconds: 30 * 60),
                                alert: .paceZone(zone, vdot: vdot)
                            )
                            return WatchWorkoutPayload(
                                name: "\(zone.displayName) · 30 min",
                                subtitle: paceZones[zone].formatted(unit: unit),
                                zoneLetter: zone.letter,
                                blocks: [.step(step)]
                            )
                        }
                        return WatchSchedulePayload(sessions: watchSessions, paceTemplates: paceTemplates)
                    }
                    guard let schedPayload else { return }
                    try? await watchConnectivityClient.sendSchedule(schedPayload)
                }

            case let .paceChipTapped(zone):
                let template = makePaceFocusTemplate(zone: zone, vdot: state.currentVDOT)
                return .send(.delegate(.openWorkoutInWorkshop(template, source: .template, isTodaySession: true)))

            case let .sessionTapped(session):
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)
                let isToday = session.dayOfWeek == PlannedSession.dayOfWeek(for: now)
                state.path.append(.editor(WorkoutEditor.State(
                    loading: template,
                    asCopy: true,
                    source: .planSession,
                    isTodaySession: isToday,
                    planSession: session
                )))
                return .none

            case let .quickStartSession(session):
                state.quickStartSendingSessionId = session.id
                let id = session.id
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)
                return .run { [hkWatchTriggerClient] send in
                    await send(.quickStartResponse(sessionId: id, Result {
                        try await hkWatchTriggerClient.startWatchSession(
                            WatchWorkoutPayload(name: template.name, blocks: template.blocks)
                        )
                    }))
                }

            case let .quickStartResponse(sessionId, .success):
                if state.quickStartSendingSessionId == sessionId {
                    state.quickStartSendingSessionId = nil
                }
                return .none

            case let .quickStartResponse(sessionId, .failure(error)):
                if state.quickStartSendingSessionId == sessionId {
                    state.quickStartSendingSessionId = nil
                }
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                state.quickStartAlert = AlertState {
                    TextState("Couldn't send to Watch")
                } message: {
                    TextState(message)
                }
                return .none

            case .quickStartAlert:
                return .none

            case let .swapSession(session, newType, variantNote):
                let note = variantNote ?? ""
                return .merge(
                    .run { [database] _ in
                        try await database.write { db in
                            try PlannedSession
                                .where { $0.id.eq(session.id) }
                                .update {
                                    $0.sessionType = #bind(newType)
                                    $0.notes = #bind(note)
                                }
                                .execute(db)
                        }
                    },
                    .send(.watchScheduleSync)
                )

            case let .path(.element(_, .weekSchedule(.delegate(.openSession(session, isToday))))):
                // Push the editor onto Plan's own stack — Back from there
                // returns to Full Schedule, not the Workshop tab.
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)
                state.path.append(.editor(WorkoutEditor.State(
                    loading: template,
                    asCopy: true,
                    source: .planSession,
                    isTodaySession: isToday,
                    planSession: session
                )))
                return .none

            case let .path(.element(_, .weekSchedule(.delegate(.swapSession(session, to: newType, variantNote: variantNote))))):
                return .send(.swapSession(session, to: newType, variantNote: variantNote))

            case let .path(.element(_, .editor(.delegate(.swapSession(session, to: newType, variantNote: variantNote))))):
                return .send(.swapSession(session, to: newType, variantNote: variantNote))

            // Editor opened inside Plan still lets the user save a copy to
            // Yours — same delegate plumbing as the Workshop-side editor.
            case let .path(.element(_, .editor(.delegate(.requestDuplicate(template))))):
                return .run { [repository] _ in
                    _ = try await repository.save(template)
                }

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
        .ifLet(\.$quickStartAlert, action: \.quickStartAlert)
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
        public var watchAvailable: Bool
        public var quickStartStatus: QuickStartStatus = .idle
        @Presents public var alert: AlertState<Action.Alert>?

        public init(watchAvailable: Bool = true) {
            self.watchAvailable = watchAvailable
        }

        public enum QuickStartStatus: Equatable {
            case idle
            case sending(sessionId: UUID)
            case sent
        }
    }
    public enum Action {
        /// `isToday`: this session is the current week's session for today
        /// — forwarded to `WorkoutEditor.State.isTodaySession` so "Start
        /// Workout" is only offered for today's actual session.
        case sessionTapped(PlannedSession)
        /// Skips the editor and pushes the workout straight to the Watch.
        /// Surfaces an alert on failure; otherwise just sets `sent`.
        case quickStartTapped(PlannedSession, vdot: Double)
        case quickStartResponse(Result<Void, any Error>)
        /// Clears the brief "Sent" confirmation back to idle — debounces
        /// the button so an accidental second tap doesn't immediately
        /// re-schedule the workout.
        case quickStartStatusReset
        case alert(PresentationAction<Alert>)
        /// Substitute a planned session with an alternative type chosen from
        /// the context menu. Delegates the DB write up to `TrainingPlan`.
        case swapSession(PlannedSession, to: SessionType, variantNote: String?)
        case delegate(Delegate)
        public enum Alert: Equatable {}
        public enum Delegate: Equatable {
            case openSession(PlannedSession, isToday: Bool)
            case swapSession(PlannedSession, to: SessionType, variantNote: String?)
        }
    }

    @Dependency(\.date.now) var now
    @Dependency(\.hkWatchTriggerClient) var hkWatchTriggerClient
    @Dependency(\.continuousClock) var clock

    /// How long the "Sent" confirmation stays up before the button reverts
    /// to "Start" — long enough to read, short enough that a genuine
    /// re-send isn't blocked for long.
    static let sentConfirmationDuration: Duration = .seconds(3)

    public init() {}
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .sessionTapped(s):
                let isToday = s.dayOfWeek == PlannedSession.dayOfWeek(for: now)
                return .send(.delegate(.openSession(s, isToday: isToday)))

            case let .quickStartTapped(session, vdot):
                guard state.watchAvailable else { return .none }
                state.quickStartStatus = .sending(sessionId: session.id)
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: vdot)
                return .run { [hkWatchTriggerClient] send in
                    await send(.quickStartResponse(Result {
                        try await hkWatchTriggerClient.startWatchSession(
                            WatchWorkoutPayload(name: template.name, blocks: template.blocks)
                        )
                    }))
                }

            case .quickStartResponse(.success):
                state.quickStartStatus = .sent
                return .run { [clock] send in
                    try await clock.sleep(for: Self.sentConfirmationDuration)
                    await send(.quickStartStatusReset)
                }

            case .quickStartStatusReset:
                if state.quickStartStatus == .sent {
                    state.quickStartStatus = .idle
                }
                return .none

            case let .quickStartResponse(.failure(error)):
                state.quickStartStatus = .idle
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                state.alert = AlertState {
                    TextState("Couldn't send to Watch")
                } message: {
                    TextState(message)
                }
                return .none

            case let .swapSession(session, to: newType, variantNote: variantNote):
                return .send(.delegate(.swapSession(session, to: newType, variantNote: variantNote)))

            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
