import Foundation
import RunCraftModels
import Testing
import TrainingPlanFeature

@Suite("TrainingPlanGenerator")
struct TrainingPlanGeneratorTests {

    private let sampleGoal = RaceGoal(
        name: "Sun Moon Lake 29K",
        targetDate: Calendar.current.date(byAdding: .weekOfYear, value: 17, to: Date())!,
        distanceKm: 29,
        currentVDOT: 40
    )

    @Test("Generates exactly 16 weeks")
    func generates16Weeks() {
        let (weeks, _) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40)
        #expect(weeks.count == 16)
    }

    @Test("Week numbers are 1–16 in order")
    func weekNumbersSequential() {
        let (weeks, _) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40)
        let numbers = weeks.map(\.weekNumber)
        #expect(numbers == Array(1...16))
    }

    @Test("Phase distribution matches Jack Daniels structure")
    func phaseDistribution() {
        let (weeks, _) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40)
        let baseWeeks  = weeks.filter { $0.phase == .base  }.count
        let buildWeeks = weeks.filter { $0.phase == .build }.count
        let peakWeeks  = weeks.filter { $0.phase == .peak  }.count
        let taperWeeks = weeks.filter { $0.phase == .taper }.count
        #expect(baseWeeks  == 4)
        #expect(buildWeeks == 4)
        #expect(peakWeeks  == 4)
        #expect(taperWeeks == 4)
    }

    @Test("Each week has exactly 7 sessions (including rest days)")
    func eachWeekHas7Sessions() {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40)
        for week in weeks {
            let count = sessions.filter { $0.weekId == week.id }.count
            #expect(count == 7, "Week \(week.weekNumber) has \(count) sessions, expected 7")
        }
    }

    @Test("All session weekId references a valid week")
    func sessionWeekIdValid() {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40)
        let weekIds = Set(weeks.map(\.id))
        for session in sessions {
            #expect(weekIds.contains(session.weekId))
        }
    }

    @Test("Peak phase has interval sessions")
    func peakHasIntervals() {
        let (weeks, sessions) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40)
        let peakWeekIds = weeks.filter { $0.phase == .peak }.map(\.id)
        let peakIntervals = sessions.filter {
            peakWeekIds.contains($0.weekId) && $0.sessionType == .interval
        }
        #expect(!peakIntervals.isEmpty, "Peak phase should include interval sessions")
    }

    @Test("Taper volume is lower than peak volume")
    func taperVolumeLowerThanPeak() {
        let (weeks, _) = TrainingPlanGenerator.generate(goal: sampleGoal, vdot: 40)
        let peakKm  = weeks.filter { $0.phase == .peak  }.map(\.targetWeeklyKm).max() ?? 0
        let taperKm = weeks.filter { $0.phase == .taper }.map(\.targetWeeklyKm).max() ?? 0
        #expect(taperKm < peakKm, "Taper weekly km (\(taperKm)) should be less than peak (\(peakKm))")
    }
}
