import Foundation
import RunCraftModels
import Testing
import TrainingPlanFeature
import VDOTEngine

/// Exhaustive coverage of `TrainingPlanGenerator.generate(availableDays:longRunDay:)`
/// across every non-empty subset of weekdays a runner could pick.
@Suite("TrainingPlanGenerator — flexible training days")
struct FlexibleTrainingDaysTests {

    private let sampleGoal = RaceGoal(
        name: "Sun Moon Lake 29K",
        targetDate: Calendar.current.date(byAdding: .weekOfYear, value: 17, to: Date())!,
        distanceKm: 29,
        currentVDOT: 40
    )

    private static let hardTypes: Set<SessionType> = [.long, .tempo, .interval, .repetition]

    /// All 127 non-empty subsets of weekdays 1...7 (Mon...Sun).
    private static let allNonEmptyDaySubsets: [Set<Int>] = {
        let days = Array(1...7)
        var subsets: [Set<Int>] = []
        for mask in 1..<(1 << days.count) {
            var subset: Set<Int> = []
            for (i, day) in days.enumerated() where mask & (1 << i) != 0 {
                subset.insert(day)
            }
            subsets.append(subset)
        }
        return subsets
    }()

    private static let multiDaySubsets = allNonEmptyDaySubsets.filter { $0.count >= 2 }

    // MARK: - Shape

    @Test("Every week has exactly 7 sessions, one per weekday", arguments: allNonEmptyDaySubsets)
    func everyWeekCovers7Days(availableDays: Set<Int>) {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        for week in weeks {
            let weekSessions = sessions.filter { $0.weekId == week.id }
            #expect(weekSessions.count == 7)
            #expect(Set(weekSessions.map(\.dayOfWeek)) == Set(1...7))
        }
    }

    @Test("Days outside availableDays are always rest", arguments: allNonEmptyDaySubsets)
    func nonAvailableDaysAreRest(availableDays: Set<Int>) {
        let (_, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        for session in sessions where !availableDays.contains(session.dayOfWeek) {
            #expect(session.sessionType == .rest)
        }
    }

    @Test("Rest sessions never carry a distance or pace zone", arguments: allNonEmptyDaySubsets)
    func restSessionsAreEmpty(availableDays: Set<Int>) {
        let (_, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        for session in sessions where session.sessionType == .rest {
            #expect(session.targetDistanceKm == nil)
            #expect(session.targetPaceZone == nil)
        }
    }

    @Test("Non-rest sessions carry a positive distance, the correct pace zone, and no baked pace text",
          arguments: allNonEmptyDaySubsets)
    func nonRestSessionsAreWellFormed(availableDays: Set<Int>) {
        let (_, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        let expectedZones: [SessionType: PaceZoneName] = [
            .easy: .easy, .long: .easy, .tempo: .threshold, .interval: .interval, .repetition: .repetition,
        ]
        for session in sessions where session.sessionType != .rest {
            #expect((session.targetDistanceKm ?? 0) > 0)
            #expect(session.targetPaceZone == expectedZones[session.sessionType])
            #expect(!session.notes.lowercased().contains("pace"))
            #expect(!session.notes.contains(":"))
        }
    }

    // MARK: - Maintenance mode (1 day/week)

    @Test("A single available day means a single easy run, every phase", arguments: 1...7)
    func singleDayIsMaintenanceMode(day: Int) {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: [day])
        for week in weeks {
            let weekSessions = sessions.filter { $0.weekId == week.id }
            let running = weekSessions.filter { $0.sessionType != .rest }
            #expect(running.count == 1)
            #expect(running.first?.sessionType == .easy)
            #expect(running.first?.dayOfWeek == day)
            #expect(running.first?.targetDistanceKm == 5)
        }
    }

    // MARK: - Session budget

    @Test("Running days never exceed the number of available days, and at least one is scheduled",
          arguments: allNonEmptyDaySubsets)
    func runningDaysWithinBudget(availableDays: Set<Int>) {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        for week in weeks {
            let runningDays = sessions.filter { $0.weekId == week.id && $0.sessionType != .rest }.count
            #expect(runningDays >= 1)
            #expect(runningDays <= availableDays.count)
        }
    }

    // MARK: - Long run placement

    @Test("Taper never schedules a long run", arguments: allNonEmptyDaySubsets)
    func taperHasNoLongRun(availableDays: Set<Int>) {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        let taperWeekIds = Set(weeks.filter { $0.phase == .taper }.map(\.id))
        let longRuns = sessions.filter { taperWeekIds.contains($0.weekId) && $0.sessionType == .long }
        #expect(longRuns.isEmpty)
    }

    @Test("Non-taper phases get exactly one long run, on an available day, once 2+ days are available",
          arguments: multiDaySubsets)
    func nonTaperHasOneLongRun(availableDays: Set<Int>) {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        for week in weeks where week.phase != .taper {
            let longRuns = sessions.filter { $0.weekId == week.id && $0.sessionType == .long }
            #expect(longRuns.count == 1, "phase \(week.phase) should have exactly 1 long run")
            if let longRun = longRuns.first {
                #expect(availableDays.contains(longRun.dayOfWeek))
            }
        }
    }

    @Test("Long run defaults to Sunday when all 7 days are available")
    func longRunDefaultsToSunday() {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: Set(1...7))
        for week in weeks where week.phase != .taper {
            let longRun = sessions.first { $0.weekId == week.id && $0.sessionType == .long }
            #expect(longRun?.dayOfWeek == 7)
        }
    }

    @Test("Long run falls back to Saturday when Sunday isn't available")
    func longRunFallsBackToSaturday() {
        let availableDays = Set(1...6) // Mon...Sat
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        for week in weeks where week.phase != .taper {
            let longRun = sessions.first { $0.weekId == week.id && $0.sessionType == .long }
            #expect(longRun?.dayOfWeek == 6)
        }
    }

    @Test("Explicit longRunDay is honored when it's available")
    func explicitLongRunDayHonored() {
        let (weeks, sessions) = TrainingPlanGenerator.generate(
            goal: sampleGoal, vdot: 40, availableDays: Set(1...7), longRunDay: 6
        )
        for week in weeks where week.phase != .taper {
            let longRun = sessions.first { $0.weekId == week.id && $0.sessionType == .long }
            #expect(longRun?.dayOfWeek == 6)
        }
    }

    @Test("Explicit longRunDay falls back to the weekend default when it isn't available")
    func explicitLongRunDayIgnoredWhenUnavailable() {
        let availableDays = Set(1...6) // Mon...Sat, no Sunday
        let (weeks, sessions) = TrainingPlanGenerator.generate(
            goal: sampleGoal, vdot: 40, availableDays: availableDays, longRunDay: 7
        )
        for week in weeks where week.phase != .taper {
            let longRun = sessions.first { $0.weekId == week.id && $0.sessionType == .long }
            #expect(longRun?.dayOfWeek == 6)
        }
    }

    // MARK: - Spacing

    @Test("Hard sessions avoid back-to-back placement whenever availableDays makes it possible",
          arguments: multiDaySubsets)
    func hardSessionsAvoidAdjacencyWhenFeasible(availableDays: Set<Int>) {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40, availableDays: availableDays)
        for week in weeks {
            let hardDays = sessions
                .filter { $0.weekId == week.id && Self.hardTypes.contains($0.sessionType) }
                .map(\.dayOfWeek)
                .sorted()
            guard hardDays.count >= 2 else { continue }

            let hasAdjacentPair = hardDays.indices.contains { i in
                hardDays[(i + 1)...].contains { Self.circularDistance(hardDays[i], $0) < 2 }
            }
            guard hasAdjacentPair else { continue }

            #expect(
                !Self.hasFullySpacedSubset(count: hardDays.count, in: availableDays),
                "week \(week.weekNumber) (\(week.phase)) has adjacent hard days \(hardDays) even though \(availableDays.sorted()) admits a fully-spaced arrangement"
            )
        }
    }

    // MARK: - Helpers (mirror the generator's own spacing rules, for brute-force verification)

    private static func circularDistance(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b)
        return min(diff, 7 - diff)
    }

    /// Brute-force: does some `count`-sized subset of `days` have all pairwise
    /// circular distances >= 2?
    private static func hasFullySpacedSubset(count: Int, in days: Set<Int>) -> Bool {
        let sorted = days.sorted()
        guard count <= sorted.count else { return false }
        return combinations(of: sorted, choose: count).contains { candidate in
            for i in 0..<candidate.count {
                for j in (i + 1)..<candidate.count where circularDistance(candidate[i], candidate[j]) < 2 {
                    return false
                }
            }
            return true
        }
    }

    private static func combinations(of array: [Int], choose: Int) -> [[Int]] {
        guard choose > 0 else { return [[]] }
        guard choose <= array.count else { return [] }
        guard choose < array.count else { return [array] }
        var result: [[Int]] = []
        for i in 0..<array.count {
            let rest = Array(array[(i + 1)...])
            guard rest.count >= choose - 1 else { break }
            for combo in combinations(of: rest, choose: choose - 1) {
                result.append([array[i]] + combo)
            }
        }
        return result
    }
}
