import Foundation
import Testing
import VDOTEngine
@testable import RunCraftModels

@Suite("WorkoutTemplate estimates")
struct WorkoutTemplateTests {

    @Test("Distance is derived from a .time goal via the step's pace alert")
    func distanceDerivedFromTimeGoal() {
        let template = WorkoutTemplate(
            name: "Easy Recovery Run",
            blocks: [
                .step(WorkoutStep(
                    kind: .work,
                    goal: .time(seconds: 1800),
                    alert: .paceZone(.easy, vdot: 40)
                )),
            ]
        )

        #expect(template.estimatedDurationSeconds == 1800)

        let range = VDOTCalculator.paceRange(for: .easy, vdot: 40)
        let secPerKm = Double(Int(range.lower.rounded()) + Int(range.upper.rounded())) / 2
        let expectedMetres = 1800 / secPerKm * 1_000
        #expect(abs(template.estimatedDistanceMetres - expectedMetres) < 0.001)
    }

    @Test("Duration is derived from .distance goals, including inside a repeat group")
    func durationDerivedFromDistanceGoal() {
        let template = WorkoutTemplate(
            name: "Yasso 800s",
            blocks: [
                .step(WorkoutStep(
                    kind: .warmup,
                    goal: .time(seconds: 600),
                    alert: .paceZone(.easy, vdot: 40)
                )),
                .repeatGroup(RepeatGroup(
                    iterations: 10,
                    steps: [
                        WorkoutStep(kind: .work, goal: .distance(metres: 800), alert: .paceZone(.interval, vdot: 40)),
                        WorkoutStep(kind: .recovery, goal: .distance(metres: 400), alert: .paceZone(.easy, vdot: 40)),
                    ]
                )),
            ]
        )

        let interval = VDOTCalculator.paceRange(for: .interval, vdot: 40)
        let easy = VDOTCalculator.paceRange(for: .easy, vdot: 40)
        let intervalSecPerKm = Double(Int(interval.lower.rounded()) + Int(interval.upper.rounded())) / 2
        let easySecPerKm = Double(Int(easy.lower.rounded()) + Int(easy.upper.rounded())) / 2

        // Warmup is a .time goal, so its distance is derived from the easy pace.
        let warmupMetres = 600.0 / easySecPerKm * 1_000
        // (800 + 400) metres per iteration * 10 iterations, plus the derived warmup distance.
        let expectedMetres = warmupMetres + (800.0 + 400.0) * 10
        #expect(abs(template.estimatedDistanceMetres - expectedMetres) < 0.001)

        let workSeconds = 800.0 / 1_000 * intervalSecPerKm
        let recoverySeconds = 400.0 / 1_000 * easySecPerKm
        let expectedSeconds = 600.0 + workSeconds * 10 + recoverySeconds * 10
        #expect(abs(template.estimatedDurationSeconds - expectedSeconds) < 0.001)
    }

    @Test("summary(unit:) includes distance, duration, and step count")
    func summaryFormat() {
        let template = WorkoutTemplate(
            name: "Test",
            blocks: [
                .step(WorkoutStep(kind: .work, goal: .time(seconds: 1800), alert: .paceZone(.easy, vdot: 40))),
            ]
        )
        let summary = template.summary(unit: .perKilometre)
        #expect(summary.contains("≈"))
        #expect(summary.contains("~30 min"))
        #expect(summary.contains("1 step"))
        #expect(!summary.contains("1 steps"))
    }

    @Test("A step with no pace alert contributes nothing to the derived dimension")
    func noPaceInfo_doesNotDeriveOtherDimension() {
        let template = WorkoutTemplate(
            name: "Test",
            blocks: [
                .step(WorkoutStep(kind: .work, goal: .distance(metres: 5_000), alert: nil)),
            ]
        )
        #expect(template.estimatedDistanceMetres == 5_000)
        #expect(template.estimatedDurationSeconds == 0)
    }
}
