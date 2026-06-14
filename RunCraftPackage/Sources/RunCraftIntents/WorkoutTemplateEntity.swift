import AppIntents
import Foundation
import RunCraftModels
import VDOTEngine

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
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }
}

extension WorkoutTemplateEntity {
    /// "Template · ≈ X km · N steps" — canonical summary shown in Siri's
    /// entity subtitle and the Start Workout snippet. Uses `PaceUnit.current`
    /// since both render outside SwiftUI's environment.
    var summary: String {
        var parts: [String] = []
        if isPreset { parts.append("Template") }
        if estimatedDistanceMetres > 0 {
            parts.append("≈ \(PaceFormatting.distance(metres: estimatedDistanceMetres, unit: .current))")
        }
        parts.append("\(stepCount) step\(stepCount == 1 ? "" : "s")")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Conversion helpers

extension WorkoutTemplateEntity {
    /// Lifts the persisted `WorkoutTemplate` into the AppIntents projection.
    public init(template: WorkoutTemplate, isPreset: Bool) {
        self.init(
            id: template.id,
            name: template.name,
            isPreset: isPreset,
            stepCount: template.totalSteps,
            estimatedDistanceMetres: template.estimatedDistanceMetres
        )
    }
}
