import Foundation
import RunCraftModels

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
        easyRecoveryRun,
    ]

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
                alert: .pace(.easy)
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("YASSO-REP"),
                iterations: 10,
                steps: [
                    WorkoutStep(
                        id: stepID("YASSO-WORK"),
                        kind: .work,
                        goal: .distance(metres: 800),
                        alert: .pace(.interval)
                    ),
                    WorkoutStep(
                        id: stepID("YASSO-REC"),
                        kind: .recovery,
                        goal: .distance(metres: 400),
                        alert: .pace(.easy)
                    ),
                ]
            )),
            .step(WorkoutStep(
                id: stepID("YASSO-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .pace(.easy)
            )),
        ]
    )

    // MARK: - Tempo Run

    /// Continuous 20-minute effort at T pace. Pure threshold training.
    public static let tempoRun: WorkoutTemplate = .init(
        id: presetID("TEMPO-RUN"),
        name: "Tempo Run",
        blocks: [
            .step(WorkoutStep(
                id: stepID("TEMPO-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .pace(.easy)
            )),
            .step(WorkoutStep(
                id: stepID("TEMPO-WORK"),
                kind: .work,
                goal: .time(seconds: 20 * 60),
                alert: .pace(.tempo)
            )),
            .step(WorkoutStep(
                id: stepID("TEMPO-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .pace(.easy)
            )),
        ]
    )

    // MARK: - Threshold Cruise Intervals

    /// Daniels-style cruise intervals: 3×1 mile at T pace with 60s recoveries.
    public static let thresholdCruiseIntervals: WorkoutTemplate = .init(
        id: presetID("CRUISE-3M"),
        name: "Cruise Intervals 3×1 mile",
        blocks: [
            .step(WorkoutStep(
                id: stepID("CRUISE-WU"),
                kind: .warmup,
                goal: .time(seconds: 15 * 60),
                alert: .pace(.easy)
            )),
            .repeatGroup(RepeatGroup(
                id: groupID("CRUISE-REP"),
                iterations: 3,
                steps: [
                    WorkoutStep(
                        id: stepID("CRUISE-WORK"),
                        kind: .work,
                        goal: .distance(metres: 1609),
                        alert: .pace(.tempo)
                    ),
                    WorkoutStep(
                        id: stepID("CRUISE-REC"),
                        kind: .recovery,
                        goal: .time(seconds: 60),
                        alert: .pace(.easy)
                    ),
                ]
            )),
            .step(WorkoutStep(
                id: stepID("CRUISE-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .pace(.easy)
            )),
        ]
    )

    // MARK: - Ladder Workout

    /// Pyramid: 400-800-1200-800-400 at I pace. Classic variety session.
    public static let ladderWorkout: WorkoutTemplate = .init(
        id: presetID("LADDER"),
        name: "Ladder 400→1200→400",
        blocks: [
            .step(WorkoutStep(
                id: stepID("LAD-WU"),
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .pace(.easy)
            )),
            // Ascending leg
            .step(WorkoutStep(id: stepID("LAD-W1"), kind: .work, goal: .distance(metres: 400), alert: .pace(.interval))),
            .step(WorkoutStep(id: stepID("LAD-R1"), kind: .recovery, goal: .time(seconds: 90), alert: .pace(.easy))),
            .step(WorkoutStep(id: stepID("LAD-W2"), kind: .work, goal: .distance(metres: 800), alert: .pace(.interval))),
            .step(WorkoutStep(id: stepID("LAD-R2"), kind: .recovery, goal: .time(seconds: 120), alert: .pace(.easy))),
            .step(WorkoutStep(id: stepID("LAD-W3"), kind: .work, goal: .distance(metres: 1200), alert: .pace(.interval))),
            .step(WorkoutStep(id: stepID("LAD-R3"), kind: .recovery, goal: .time(seconds: 150), alert: .pace(.easy))),
            // Descending leg
            .step(WorkoutStep(id: stepID("LAD-W4"), kind: .work, goal: .distance(metres: 800), alert: .pace(.interval))),
            .step(WorkoutStep(id: stepID("LAD-R4"), kind: .recovery, goal: .time(seconds: 120), alert: .pace(.easy))),
            .step(WorkoutStep(id: stepID("LAD-W5"), kind: .work, goal: .distance(metres: 400), alert: .pace(.interval))),
            .step(WorkoutStep(
                id: stepID("LAD-CD"),
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .pace(.easy)
            )),
        ]
    )

    // MARK: - Easy Recovery Run

    /// Short E-pace shake-out run, ideal for the day after a hard session.
    public static let easyRecoveryRun: WorkoutTemplate = .init(
        id: presetID("EASY-RECOVERY"),
        name: "Easy Recovery Run",
        blocks: [
            .step(WorkoutStep(
                id: stepID("EASY-RUN"),
                kind: .work,
                goal: .time(seconds: 30 * 60),
                alert: .pace(.easy)
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
