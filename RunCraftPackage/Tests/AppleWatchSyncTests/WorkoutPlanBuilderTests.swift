#if canImport(WorkoutKit)
import Foundation
import RunCraftModels
import Testing
import WorkoutKit
@testable import AppleWatchSync

@Suite("WorkoutPlanBuilder")
struct WorkoutPlanBuilderTests {

    @Test("First .warmup step is hoisted into CustomWorkout.warmup slot")
    func warmup_hoisted() throws {
        let warmup  = WorkoutStep(kind: .warmup,  goal: .time(seconds: 600))
        let work    = WorkoutStep(kind: .work,    goal: .distance(metres: 1_000))
        let cooldown = WorkoutStep(kind: .cooldown, goal: .time(seconds: 600))

        let template = WorkoutTemplate(
            name: "Test",
            blocks: [.step(warmup), .step(work), .step(cooldown)]
        )

        let plan = try WorkoutPlanBuilder.makePlan(from: template)
        guard case .custom(let custom) = plan.workout else {
            Issue.record("expected a custom workout"); return
        }
        #expect(custom.warmup != nil, "warmup slot should be populated")
        #expect(custom.cooldown != nil, "cooldown slot should be populated")
        #expect(custom.blocks.count == 1, "middle work step → 1 IntervalBlock")
        #expect(custom.displayName == "Test")
    }

    @Test("Repeat group becomes a multi-iteration IntervalBlock")
    func repeatGroup_iterations() throws {
        let work     = WorkoutStep(kind: .work,     goal: .distance(metres: 400))
        let recovery = WorkoutStep(kind: .recovery, goal: .time(seconds: 90))
        let group    = RepeatGroup(iterations: 8, steps: [work, recovery])

        let template = WorkoutTemplate(name: "Reps", blocks: [.repeatGroup(group)])
        let plan = try WorkoutPlanBuilder.makePlan(from: template)
        guard case .custom(let custom) = plan.workout else {
            Issue.record("expected a custom workout"); return
        }
        #expect(custom.blocks.count == 1)
        #expect(custom.blocks.first?.iterations == 8)
        #expect(custom.blocks.first?.steps.count == 2)
    }
}
#endif
