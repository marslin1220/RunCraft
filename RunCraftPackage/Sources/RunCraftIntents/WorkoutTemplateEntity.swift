import AppIntents
import Foundation
import RunCraftModels

/// Voice-/Spotlight-facing wrapper around a `WorkoutTemplate`. Covers both
/// the built-in presets (Yasso 800s, Mona Fartlek, …) and user-saved
/// templates — they share an identity space because `WorkoutTemplate.id`
/// is unique whether the row lives in `WorkoutPresets` or in the database.
public struct WorkoutTemplateEntity: AppEntity {

    public static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: "Workout")

    public static let defaultQuery = WorkoutTemplateQuery()

    public let id: UUID
    public let name: String
    /// Built-in presets get a distinctive subtitle prefix so the runner can
    /// tell their saved workouts apart from the sample library.
    public let isPreset: Bool
    public let stepCount: Int
    public let estimatedDistanceMetres: Double

    public init(
        id: UUID,
        name: String,
        isPreset: Bool,
        stepCount: Int,
        estimatedDistanceMetres: Double
    ) {
        self.id = id
        self.name = name
        self.isPreset = isPreset
        self.stepCount = stepCount
        self.estimatedDistanceMetres = estimatedDistanceMetres
    }

    public var displayRepresentation: DisplayRepresentation {
        var subtitleParts: [String] = []
        if isPreset { subtitleParts.append("Template") }
        if estimatedDistanceMetres > 0 {
            let km = estimatedDistanceMetres / 1_000
            subtitleParts.append("≈ \(km.formatted(.number.precision(.fractionLength(0...1)))) km")
        }
        subtitleParts.append("\(stepCount) step\(stepCount == 1 ? "" : "s")")
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(subtitleParts.joined(separator: " · "))"
        )
    }
}

// MARK: - Conversion helpers

extension WorkoutTemplateEntity {
    /// Lifts the persisted `WorkoutTemplate` into the AppIntents projection.
    /// Walks the block tree once to count steps and accumulate distance.
    public init(template: WorkoutTemplate, isPreset: Bool) {
        let blocks = template.blocks
        let stepCount = blocks.reduce(0) { acc, block in
            switch block {
            case .step: acc + 1
            case .repeatGroup(let g): acc + g.steps.count * g.iterations
            }
        }
        let metres = blocks.reduce(0.0) { acc, block in
            switch block {
            case .step(let s):
                if case .distance(let m) = s.goal { return acc + m }
                return acc
            case .repeatGroup(let g):
                let per = g.steps.reduce(0.0) { sub, s in
                    if case .distance(let m) = s.goal { return sub + m }
                    return sub
                }
                return acc + per * Double(g.iterations)
            }
        }
        self.init(
            id: template.id,
            name: template.name,
            isPreset: isPreset,
            stepCount: stepCount,
            estimatedDistanceMetres: metres
        )
    }
}
