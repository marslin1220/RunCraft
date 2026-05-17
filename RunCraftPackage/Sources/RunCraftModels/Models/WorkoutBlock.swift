import Foundation

// MARK: - Block

/// A block in a workout template: either a single step or a repeated group of steps.
public enum WorkoutBlock: Identifiable, Equatable, Sendable, Codable {
    case step(WorkoutStep)
    case repeatGroup(RepeatGroup)

    public var id: UUID {
        switch self {
        case .step(let s):        s.id
        case .repeatGroup(let g): g.id
        }
    }
}

// MARK: - Step

public struct WorkoutStep: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public var kind: StepKind
    public var goal: StepGoal
    public var alert: StepAlert?

    public init(
        id: UUID = UUID(),
        kind: StepKind,
        goal: StepGoal = .openEnded,
        alert: StepAlert? = nil
    ) {
        self.id = id
        self.kind = kind
        self.goal = goal
        self.alert = alert
    }
}

public enum StepKind: String, CaseIterable, Equatable, Sendable, Codable {
    case warmup
    case work
    case recovery
    case cooldown

    public var displayName: String {
        switch self {
        case .warmup:   "Warm-up"
        case .work:     "Run"
        case .recovery: "Recovery"
        case .cooldown: "Cool-down"
        }
    }

    public var symbolName: String {
        switch self {
        case .warmup:   "flame"
        case .work:     "figure.run"
        case .recovery: "figure.walk"
        case .cooldown: "wind"
        }
    }
}

public enum StepGoal: Equatable, Sendable, Codable {
    case openEnded
    case distance(metres: Double)
    case time(seconds: Int)

    public var displayText: String {
        switch self {
        case .openEnded:
            "Open"
        case .distance(let m):
            m >= 1_000
                ? "\((m / 1_000).formatted(.number.precision(.fractionLength(0...2)))) km"
                : "\(Int(m)) m"
        case .time(let s):
            s >= 60
                ? "\(s / 60) min\(s % 60 == 0 ? "" : " \(s % 60) sec")"
                : "\(s) sec"
        }
    }
}

public enum StepAlert: Equatable, Sendable, Codable {
    /// Target one of the five Jack Daniels pace zones.
    case pace(SessionType)
    /// Target a heart rate range (BPM).
    case heartRate(min: Int, max: Int)

    public var displayText: String {
        switch self {
        case .pace(let zone):
            "\(zone.displayName) pace"
        case .heartRate(let min, let max):
            "\(min)–\(max) bpm"
        }
    }
}

// MARK: - Repeat Group

public struct RepeatGroup: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public var iterations: Int
    /// Repeat groups contain steps only — no nested groups (keeps editor simple).
    public var steps: [WorkoutStep]

    public init(
        id: UUID = UUID(),
        iterations: Int = 4,
        steps: [WorkoutStep] = []
    ) {
        self.id = id
        self.iterations = iterations
        self.steps = steps
    }
}
