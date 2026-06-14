import Foundation
import RunCraftModels
import VDOTEngine

/// Built-in workout templates that ship with the app.
///
/// Presets are immutable — tapping one in the library loads its blocks into
/// the editor as a *new* template (editingTemplateId = nil), so saving creates
/// a user-owned copy that can be customised independently.
public enum WorkoutPresets {

    public static let all: [WorkoutTemplate] = [
        yasso800s,
        tempoRun,
        thresholdCruiseIntervals,
        ladderWorkout,
        monaFartlek,
        hillRepeats,
        progressionRun,
        speedPyramid,
        michiganWorkout,
        norwegian4x4,
        easyRecoveryRun,
    ]

    /// Maps each built-in preset onto the `SessionType` that best describes
    /// its training stimulus — drives the section grouping in the Workshop
    /// Templates tab. Presets whose work steps span more than one pace zone
    /// (no single dominant stimulus) fall back to `.mixed`.
    public static let categories: [WorkoutTemplate.ID: SessionType] = [
        yasso800s.id:                .interval,
        tempoRun.id:                 .tempo,
        thresholdCruiseIntervals.id: .tempo,
        ladderWorkout.id:            .interval,
        monaFartlek.id:              .fartlek,
        hillRepeats.id:              .interval,
        progressionRun.id:           .mixed,
        speedPyramid.id:             .interval,
        michiganWorkout.id:          .mixed,
        norwegian4x4.id:             .interval,
        easyRecoveryRun.id:          .easy,
    ]

    /// Falls back to `.mixed` for any preset not listed in `categories`.
    public static func category(for template: WorkoutTemplate) -> SessionType {
        categories[template.id] ?? .mixed
    }

    // MARK: - Yasso 800s

    /// 10×800m at I pace with 400m recoveries. Bart Yasso's signature workout —
    /// historically used as a marathon time predictor.
    public static let yasso800s: WorkoutTemplate = .init(
        id: presetID("YASSO-800"),
        name: "Yasso 800s",
        blocks: [
            .step(WorkoutStep(
                id: stepID("YASSO-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("YASSO-REP"),
                iterations: 10,
                steps: [
                    WorkoutStep(
                        id: stepID("YASSO-WORK"),
                        kind: .work,
                        goal: .distance(metres: 800),
                        alert: .paceZone(PaceZoneName.interval, vdot: 40)
                    ),
                    WorkoutStep(
                        id: stepID("YASSO-REC"),
                        kind: .recovery,
                        goal: .distance(metres: 400),
                        alert: .paceZone(PaceZoneName.easy, vdot: 40)
                    ),
                ]
            )),
            .step(WorkoutStep(
                id: stepID("YASSO-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Tempo Run

    /// Continuous 20-minute effort at T pace. Pure threshold training.
    public static let tempoRun: WorkoutTemplate = .init(
        id: presetID("TEMPO-RUN"),
        // Descriptive — translated per locale. Named-after-person presets
        // (Yasso, Mona) stay English as proper nouns. See LOCALIZATION.md §2.4.
        name: String(localized: "Tempo Run", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("TEMPO-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .step(WorkoutStep(
                id: stepID("TEMPO-WORK"),
                kind: .work,
                goal: .time(seconds: 20 * 60),
                alert: .paceZone(PaceZoneName.threshold, vdot: 40)
            )),
            .step(WorkoutStep(
                id: stepID("TEMPO-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Threshold Cruise Intervals

    /// Daniels-style cruise intervals: 3×1 mile at T pace with 60s recoveries.
    public static let thresholdCruiseIntervals: WorkoutTemplate = .init(
        id: presetID("CRUISE-3M"),
        name: String(localized: "Cruise Intervals 3×1 mile", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("CRUISE-WU"),
                kind: .warmup,
                goal: .time(seconds: 15 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("CRUISE-REP"),
                iterations: 3,
                steps: [
                    WorkoutStep(
                        id: stepID("CRUISE-WORK"),
                        kind: .work,
                        goal: .distance(metres: 1609),
                        alert: .paceZone(PaceZoneName.threshold, vdot: 40)
                    ),
                    WorkoutStep(
                        id: stepID("CRUISE-REC"),
                        kind: .recovery,
                        goal: .time(seconds: 60),
                        alert: .paceZone(PaceZoneName.easy, vdot: 40)
                    ),
                ]
            )),
            .step(WorkoutStep(
                id: stepID("CRUISE-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Ladder Workout

    /// Pyramid: 400-800-1200-800-400 at I pace. Classic variety session.
    public static let ladderWorkout: WorkoutTemplate = .init(
        id: presetID("LADDER"),
        name: String(localized: "Ladder 400→1200→400", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("LAD-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            // Ascending leg
            .step(WorkoutStep(id: stepID("LAD-W1"), kind: .work, goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("LAD-R1"), kind: .recovery, goal: .time(seconds: 90), alert: .paceZone(PaceZoneName.easy, vdot: 40))),
            .step(WorkoutStep(id: stepID("LAD-W2"), kind: .work, goal: .distance(metres: 800), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("LAD-R2"), kind: .recovery, goal: .time(seconds: 120), alert: .paceZone(PaceZoneName.easy, vdot: 40))),
            .step(WorkoutStep(id: stepID("LAD-W3"), kind: .work, goal: .distance(metres: 1200), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("LAD-R3"), kind: .recovery, goal: .time(seconds: 150), alert: .paceZone(PaceZoneName.easy, vdot: 40))),
            // Descending leg
            .step(WorkoutStep(id: stepID("LAD-W4"), kind: .work, goal: .distance(metres: 800), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("LAD-R4"), kind: .recovery, goal: .time(seconds: 120), alert: .paceZone(PaceZoneName.easy, vdot: 40))),
            .step(WorkoutStep(id: stepID("LAD-W5"), kind: .work, goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(
                id: stepID("LAD-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Mona Fartlek
    //
    // Steve Moneghetti's signature "speed play" — 20 minutes of varied surges
    // and equal-duration floats. Four descending blocks teach the legs to
    // shift gears under fatigue. Float recoveries stay aerobic (E pace), not
    // standing rests, so it doubles as a tempo-flavoured session.

    public static let monaFartlek: WorkoutTemplate = .init(
        id: presetID("MONA-FARTLEK"),
        name: "Mona Fartlek",
        blocks: [
            .step(WorkoutStep(
                id: stepID("MONA-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("MONA-90"),
                iterations: 2,
                steps: [
                    WorkoutStep(id: stepID("MONA-90-W"), kind: .work,     goal: .time(seconds: 90), alert: .paceZone(PaceZoneName.interval, vdot: 40)),
                    WorkoutStep(id: stepID("MONA-90-R"), kind: .recovery, goal: .time(seconds: 90), alert: .paceZone(PaceZoneName.easy,     vdot: 40)),
                ]
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("MONA-60"),
                iterations: 4,
                steps: [
                    WorkoutStep(id: stepID("MONA-60-W"), kind: .work,     goal: .time(seconds: 60), alert: .paceZone(PaceZoneName.interval, vdot: 40)),
                    WorkoutStep(id: stepID("MONA-60-R"), kind: .recovery, goal: .time(seconds: 60), alert: .paceZone(PaceZoneName.easy,     vdot: 40)),
                ]
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("MONA-30"),
                iterations: 4,
                steps: [
                    WorkoutStep(id: stepID("MONA-30-W"), kind: .work,     goal: .time(seconds: 30), alert: .paceZone(PaceZoneName.interval, vdot: 40)),
                    WorkoutStep(id: stepID("MONA-30-R"), kind: .recovery, goal: .time(seconds: 30), alert: .paceZone(PaceZoneName.easy,     vdot: 40)),
                ]
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("MONA-15"),
                iterations: 4,
                steps: [
                    WorkoutStep(id: stepID("MONA-15-W"), kind: .work,     goal: .time(seconds: 15), alert: .paceZone(PaceZoneName.repetition, vdot: 40)),
                    WorkoutStep(id: stepID("MONA-15-R"), kind: .recovery, goal: .time(seconds: 15), alert: .paceZone(PaceZoneName.easy,       vdot: 40)),
                ]
            )),
            .step(WorkoutStep(
                id: stepID("MONA-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Hill Repeats
    //
    // Short uphill efforts at interval-pace effort with walk-jog downhill
    // recoveries. Hills add strength + cardiovascular load without
    // joint impact — a track substitute when no oval is available.
    // Effort-based: the runner picks any hill and runs hard up.

    public static let hillRepeats: WorkoutTemplate = .init(
        id: presetID("HILL-REPEATS"),
        name: String(localized: "Hill Repeats", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("HILL-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("HILL-REP"),
                iterations: 8,
                steps: [
                    WorkoutStep(
                        id: stepID("HILL-UP"),
                        kind: .work,
                        goal: .time(seconds: 60),
                        alert: .paceZone(PaceZoneName.interval, vdot: 40)
                    ),
                    WorkoutStep(
                        id: stepID("HILL-DOWN"),
                        kind: .recovery,
                        goal: .time(seconds: 90),
                        alert: .paceZone(PaceZoneName.easy, vdot: 40)
                    ),
                ]
            )),
            .step(WorkoutStep(
                id: stepID("HILL-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Progression Run
    //
    // 60 minutes that ramps from Easy through Marathon to Threshold pace.
    // Teaches the body to handle pace transitions and accelerates fatigued
    // — a near-perfect race-rehearsal session for marathon training blocks.

    public static let progressionRun: WorkoutTemplate = .init(
        id: presetID("PROGRESSION"),
        name: String(localized: "Progression Run", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("PROG-E"),
                kind: .work,
                goal: .time(seconds: 20 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .step(WorkoutStep(
                id: stepID("PROG-M"),
                kind: .work,
                goal: .time(seconds: 20 * 60),
                alert: .paceZone(PaceZoneName.marathon, vdot: 40)
            )),
            .step(WorkoutStep(
                id: stepID("PROG-T"),
                kind: .work,
                goal: .time(seconds: 20 * 60),
                alert: .paceZone(PaceZoneName.threshold, vdot: 40)
            )),
        ]
    )

    // MARK: - Speed Pyramid
    //
    // 200 → 400 → 600 → 800 → 600 → 400 → 200 at I pace with mostly
    // 400m recoveries. Pyramid structure builds confidence — the longest
    // rep sits at the top, after which the descending efforts feel
    // increasingly achievable.

    public static let speedPyramid: WorkoutTemplate = .init(
        id: presetID("SPEED-PYRAMID"),
        name: String(localized: "Speed Pyramid", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("PYR-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            // Ascending
            .step(WorkoutStep(id: stepID("PYR-W1"), kind: .work,     goal: .distance(metres: 200), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-R1"), kind: .recovery, goal: .distance(metres: 200), alert: .paceZone(PaceZoneName.easy,     vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-W2"), kind: .work,     goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-R2"), kind: .recovery, goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.easy,     vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-W3"), kind: .work,     goal: .distance(metres: 600), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-R3"), kind: .recovery, goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.easy,     vdot: 40))),
            // Peak
            .step(WorkoutStep(id: stepID("PYR-W4"), kind: .work,     goal: .distance(metres: 800), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-R4"), kind: .recovery, goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.easy,     vdot: 40))),
            // Descending
            .step(WorkoutStep(id: stepID("PYR-W5"), kind: .work,     goal: .distance(metres: 600), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-R5"), kind: .recovery, goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.easy,     vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-W6"), kind: .work,     goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-R6"), kind: .recovery, goal: .distance(metres: 400), alert: .paceZone(PaceZoneName.easy,     vdot: 40))),
            .step(WorkoutStep(id: stepID("PYR-W7"), kind: .work,     goal: .distance(metres: 200), alert: .paceZone(PaceZoneName.interval, vdot: 40))),
            .step(WorkoutStep(
                id: stepID("PYR-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Michigan Workout
    //
    // Ron Warhurst's signature session — 1600 → 1200 → 800 → 400 at
    // threshold pace with short jog recoveries, last 400m at I pace.
    // Named after the University of Michigan track team. Kept in English
    // because the name carries cultural weight in the running world.

    public static let michiganWorkout: WorkoutTemplate = .init(
        id: presetID("MICHIGAN"),
        // Proper noun — never localized.
        name: "Michigan Workout",
        blocks: [
            .step(WorkoutStep(
                id: stepID("MICH-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .step(WorkoutStep(id: stepID("MICH-W1"), kind: .work,     goal: .distance(metres: 1609), alert: .paceZone(PaceZoneName.threshold, vdot: 40))),
            .step(WorkoutStep(id: stepID("MICH-R1"), kind: .recovery, goal: .time(seconds: 4 * 60), alert: .paceZone(PaceZoneName.easy,      vdot: 40))),
            .step(WorkoutStep(id: stepID("MICH-W2"), kind: .work,     goal: .distance(metres: 1200), alert: .paceZone(PaceZoneName.threshold, vdot: 40))),
            .step(WorkoutStep(id: stepID("MICH-R2"), kind: .recovery, goal: .time(seconds: 3 * 60), alert: .paceZone(PaceZoneName.easy,      vdot: 40))),
            .step(WorkoutStep(id: stepID("MICH-W3"), kind: .work,     goal: .distance(metres: 800),  alert: .paceZone(PaceZoneName.threshold, vdot: 40))),
            .step(WorkoutStep(id: stepID("MICH-R3"), kind: .recovery, goal: .time(seconds: 2 * 60), alert: .paceZone(PaceZoneName.easy,      vdot: 40))),
            .step(WorkoutStep(id: stepID("MICH-W4"), kind: .work,     goal: .distance(metres: 400),  alert: .paceZone(PaceZoneName.interval,  vdot: 40))),
            .step(WorkoutStep(
                id: stepID("MICH-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Norwegian 4×4
    //
    // The "4x4" VO2max-interval protocol from Norwegian endurance
    // research (Helgerud et al.), popularized by the Ingebrigtsen
    // training group: 4×4 minutes at I pace with 3-minute easy jog
    // recoveries — longer, steadier reps than Yasso 800s' shorter
    // 800m efforts.

    public static let norwegian4x4: WorkoutTemplate = .init(
        id: presetID("NOR-4X4"),
        name: String(localized: "Norwegian 4×4", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("NOR-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("NOR-REP"),
                iterations: 4,
                steps: [
                    WorkoutStep(
                        id: stepID("NOR-WORK"),
                        kind: .work,
                        goal: .time(seconds: 4 * 60),
                        alert: .paceZone(PaceZoneName.interval, vdot: 40)
                    ),
                    WorkoutStep(
                        id: stepID("NOR-REC"),
                        kind: .recovery,
                        goal: .time(seconds: 3 * 60),
                        alert: .paceZone(PaceZoneName.easy, vdot: 40)
                    ),
                ]
            )),
            .step(WorkoutStep(
                id: stepID("NOR-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - Easy Recovery Run

    /// Short E-pace shake-out run, ideal for the day after a hard session.
    public static let easyRecoveryRun: WorkoutTemplate = .init(
        id: presetID("EASY-RECOVERY"),
        name: String(localized: "Easy Recovery Run", bundle: .module),
        blocks: [
            .step(WorkoutStep(
                id: stepID("EASY-RUN"),
                kind: .work,
                goal: .time(seconds: 30 * 60),
                alert: .paceZone(PaceZoneName.easy, vdot: 40)
            )),
        ]
    )

    // MARK: - ID helpers

    /// Deterministic UUIDs so previews and identity stay stable across launches.
    private static func presetID(_ tag: String) -> UUID {
        // SHA-style fixed: hash the tag into a stable UUID5 namespace.
        // For simplicity we use a name-based UUID by padding/truncating tag bytes.
        return uuid(seed: "preset.\(tag)")
    }
    private static func groupID(_ tag: String) -> UUID  { uuid(seed: "group.\(tag)") }
    private static func stepID(_ tag: String)  -> UUID  { uuid(seed: "step.\(tag)") }

    private static func uuid(seed: String) -> UUID {
        var bytes = Array(seed.utf8)
        while bytes.count < 16 { bytes.append(0) }
        let prefix = Array(bytes.prefix(16))
        let tuple = (
            prefix[0],  prefix[1],  prefix[2],  prefix[3],
            prefix[4],  prefix[5],  prefix[6],  prefix[7],
            prefix[8],  prefix[9],  prefix[10], prefix[11],
            prefix[12], prefix[13], prefix[14], prefix[15]
        )
        return UUID(uuid: tuple)
    }
}
