import Foundation
import Testing
@testable import RunCraftModels

@Suite("PlanSessionAdapter")
struct PlanSessionAdapterTests {

    // MARK: - Rest

    @Test("Rest day produces an empty block list")
    func rest_isEmpty() {
        let session = makeSession(.rest)
        let template = PlanSessionAdapter.makeTemplate(from: session, vdot: 40)
        #expect(template.blocks.isEmpty)
    }

    // MARK: - Easy / Long

    @Test("Easy with distance produces one work step at E pace, distance goal in metres",
          arguments: [SessionType.easy, .long])
    func easyOrLong_distance(_ type: SessionType) {
        let session = makeSession(type, distanceKm: 8)
        let template = PlanSessionAdapter.makeTemplate(from: session, vdot: 40)

        #expect(template.blocks.count == 1)
        guard case let .step(step) = template.blocks[0] else {
            Issue.record("expected a step block"); return
        }
        #expect(step.kind == .work)
        #expect(step.goal == .distance(metres: 8_000))
        #expect(step.alert == .paceZone(.easy, vdot: 40))
    }

    @Test("Easy with duration (no distance) produces a time goal")
    func easyOrLong_time() {
        let session = makeSession(.easy, distanceKm: nil, durationMin: 45)
        let template = PlanSessionAdapter.makeTemplate(from: session, vdot: 40)

        guard case let .step(step) = template.blocks[0] else {
            Issue.record("expected a step block"); return
        }
        #expect(step.goal == .time(seconds: 45 * 60))
    }

    @Test("Easy with neither distance nor duration falls back to 30 min")
    func easyOrLong_fallback() {
        let session = makeSession(.easy, distanceKm: nil, durationMin: nil)
        let template = PlanSessionAdapter.makeTemplate(from: session, vdot: 40)

        guard case let .step(step) = template.blocks[0] else {
            Issue.record("expected a step block"); return
        }
        #expect(step.goal == .time(seconds: 30 * 60))
    }

    // MARK: - Tempo

    @Test("Tempo with distance — warmup + tempo at 70% of total + cooldown")
    func tempo_distance() {
        let session = makeSession(.tempo, distanceKm: 10)
        let template = PlanSessionAdapter.makeTemplate(from: session, vdot: 40)

        #expect(template.blocks.count == 3)

        let kinds = template.blocks.compactMap { block -> StepKind? in
            if case let .step(s) = block { return s.kind } else { return nil }
        }
        #expect(kinds == [.warmup, .work, .cooldown])

        guard case let .step(warmup) = template.blocks[0],
              case let .step(work) = template.blocks[1],
              case let .step(cooldown) = template.blocks[2]
        else { Issue.record("expected three step blocks"); return }

        #expect(warmup.goal == .time(seconds: 10 * 60))
        #expect(warmup.alert == .paceZone(.easy, vdot: 40))

        #expect(work.goal == .distance(metres: 7_000))   // 70% of 10 km
        #expect(work.alert == .paceZone(.threshold, vdot: 40))

        #expect(cooldown.goal == .time(seconds: 10 * 60))
        #expect(cooldown.alert == .paceZone(.easy, vdot: 40))
    }

    @Test("Tempo with duration — work segment = duration − 20 min, clamped to ≥ 20")
    func tempo_duration_clamp() {
        // 60 min total → 40 min tempo
        let normal = PlanSessionAdapter.makeTemplate(
            from: makeSession(.tempo, distanceKm: nil, durationMin: 60),
            vdot: 40
        )
        guard case let .step(work) = normal.blocks[1] else {
            Issue.record("expected a work step"); return
        }
        #expect(work.goal == .time(seconds: 40 * 60))

        // 25 min total would otherwise give 5 min tempo; clamp to 20 min
        let clamped = PlanSessionAdapter.makeTemplate(
            from: makeSession(.tempo, distanceKm: nil, durationMin: 25),
            vdot: 40
        )
        guard case let .step(clampedWork) = clamped.blocks[1] else {
            Issue.record("expected a work step"); return
        }
        #expect(clampedWork.goal == .time(seconds: 20 * 60))
    }

    @Test("Tempo with neither distance nor duration falls back to 20-min work")
    func tempo_fallback() {
        let template = PlanSessionAdapter.makeTemplate(
            from: makeSession(.tempo, distanceKm: nil, durationMin: nil),
            vdot: 40
        )
        guard case let .step(work) = template.blocks[1] else {
            Issue.record("expected a work step"); return
        }
        #expect(work.goal == .time(seconds: 20 * 60))
    }

    // MARK: - Interval

    @Test("Interval — warmup + 5× (1 km work / 90 s recovery) + cooldown")
    func interval_structure() {
        let template = PlanSessionAdapter.makeTemplate(
            from: makeSession(.interval, distanceKm: 10),
            vdot: 40
        )

        #expect(template.blocks.count == 3)

        guard case .step = template.blocks[0],
              case let .repeatGroup(group) = template.blocks[1],
              case .step = template.blocks[2]
        else { Issue.record("expected step, repeat, step"); return }

        #expect(group.iterations == 5)
        #expect(group.steps.count == 2)
        #expect(group.steps[0].kind == .work)
        #expect(group.steps[0].goal == .distance(metres: 1_000))
        #expect(group.steps[0].alert == .paceZone(.interval, vdot: 40))
        #expect(group.steps[1].kind == .recovery)
        #expect(group.steps[1].goal == .time(seconds: 90))
        #expect(group.steps[1].alert == .paceZone(.easy, vdot: 40))
    }

    @Test("Interval with nil distance uses default 10 km budget (5 reps stays)")
    func interval_nilDistance_keepsDefaultIterations() {
        let template = PlanSessionAdapter.makeTemplate(
            from: makeSession(.interval, distanceKm: nil),
            vdot: 40
        )
        guard case let .repeatGroup(group) = template.blocks[1] else {
            Issue.record("expected a repeat group"); return
        }
        #expect(group.iterations == 5)
    }

    // MARK: - Repetition

    @Test("Repetition — warmup + 8× (200 m R pace / 200 m E recovery) + cooldown")
    func repetition_structure() {
        let template = PlanSessionAdapter.makeTemplate(
            from: makeSession(.repetition, distanceKm: nil),
            vdot: 40
        )

        guard case let .repeatGroup(group) = template.blocks[1] else {
            Issue.record("expected a repeat group"); return
        }
        #expect(group.iterations == 8)
        #expect(group.steps[0].goal == .distance(metres: 200))
        #expect(group.steps[0].alert == .paceZone(.repetition, vdot: 40))
        #expect(group.steps[1].goal == .distance(metres: 200))
        #expect(group.steps[1].alert == .paceZone(.easy, vdot: 40))
    }

    // MARK: - Display name

    @Test("Display name appends km when distance provided")
    func displayName_distance() {
        let template = PlanSessionAdapter.makeTemplate(
            from: makeSession(.easy, distanceKm: 8.5),
            vdot: 40
        )
        #expect(template.name == "Easy Run · 8.5 km")
    }

    @Test("Display name appends min when only duration provided")
    func displayName_duration() {
        let template = PlanSessionAdapter.makeTemplate(
            from: makeSession(.tempo, distanceKm: nil, durationMin: 30),
            vdot: 40
        )
        #expect(template.name == "Tempo Run · 30 min")
    }

    @Test("Display name omits suffix when neither distance nor duration provided")
    func displayName_bareKind() {
        let template = PlanSessionAdapter.makeTemplate(
            from: makeSession(.rest),
            vdot: 40
        )
        #expect(template.name == "Rest")
    }

    // MARK: - Identity preservation

    @Test("Template id reuses the source PlannedSession id (round-trip mapping)")
    func id_preserved() {
        let session = makeSession(.easy, distanceKm: 5)
        let template = PlanSessionAdapter.makeTemplate(from: session, vdot: 40)
        #expect(template.id == session.id)
    }

    // MARK: - VDOT propagation

    @Test("VDOT 50 produces a faster Easy pace range than VDOT 30",
          arguments: [SessionType.easy, .tempo, .interval, .repetition])
    func vdot_affectsAlertPaces(_ type: SessionType) {
        let slow = PlanSessionAdapter.makeTemplate(from: makeSession(type, distanceKm: 10), vdot: 30)
        let fast = PlanSessionAdapter.makeTemplate(from: makeSession(type, distanceKm: 10), vdot: 50)

        let slowPace = firstPaceRangeLowerBound(in: slow)
        let fastPace = firstPaceRangeLowerBound(in: fast)
        #expect(slowPace > fastPace,
                "expected VDOT 50 to produce a lower sec/km lower-bound than VDOT 30")
    }

    // MARK: - Helpers

    private func makeSession(
        _ type: SessionType,
        distanceKm: Double? = nil,
        durationMin: Int? = nil
    ) -> PlannedSession {
        PlannedSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            weekId: UUID(uuidString: "00000000-0000-0000-0000-0000000000A0")!,
            dayOfWeek: 1,
            sessionType: type,
            targetDistanceKm: distanceKm,
            targetDurationMin: durationMin,
            notes: ""
        )
    }

    /// Walks the template's blocks until it finds the first pace-range alert,
    /// returning its lower bound (sec/km). Used to compare VDOTs.
    private func firstPaceRangeLowerBound(in template: WorkoutTemplate) -> Int {
        for block in template.blocks {
            switch block {
            case let .step(s):
                if case let .paceRange(lo, _) = s.alert { return lo }
            case let .repeatGroup(g):
                for s in g.steps {
                    if case let .paceRange(lo, _) = s.alert { return lo }
                }
            }
        }
        return 0
    }
}
