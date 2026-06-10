import AppIntents
import AppleWatchSync
import Dependencies
import Foundation
import RunCraftModels
import SQLiteData
import SwiftUI
import WorkshopFeature

/// "Start Yasso 800 in RunCraft" — voice-driven workout dispatch.
///
/// Resolves the chosen template (either a built-in preset or a user-saved
/// row), builds a WorkoutKit `WorkoutPlan`, and schedules it on the paired
/// Apple Watch. The runner gets a banner on their Watch within ~1 minute.
public struct StartWorkoutIntent: AppIntent {

    public static let title: LocalizedStringResource = "Start a workout"

    public static let description = IntentDescription(
        "Send a RunCraft workout to your paired Apple Watch and start it in the Workout app.",
        categoryName: "Training"
    )

    /// Stays out of the app — the value of this intent is bypassing the
    /// UI to get straight to the run. The Watch is the destination, not
    /// the iPhone screen.
    public static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Workout",
        description: "Which template to send to your Apple Watch."
    )
    public var workout: WorkoutTemplateEntity

    public init() {}

    public init(workout: WorkoutTemplateEntity) {
        self.workout = workout
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let template = try resolveTemplate(for: workout)

        let workoutKitClient: WorkoutKitClient = Dependency(key: \DependencyValues.workoutKitClient).wrappedValue
        guard workoutKitClient.isAvailable() else {
            return .result(
                dialog: "WorkoutKit isn't available on this device. Open RunCraft to start the workout manually."
            ) {
                StartWorkoutSnippetView(workout: workout, status: .unavailable)
            }
        }

        do {
            try await workoutKitClient.openInWorkoutApp(template)
        } catch {
            return .result(
                dialog: "I couldn't send \(workout.name) to your Watch. \(error.localizedDescription)"
            ) {
                StartWorkoutSnippetView(workout: workout, status: .failed)
            }
        }

        let spoken = "Sending \(workout.name) to your Apple Watch. Open Workouts on the Watch when you're ready."
        return .result(dialog: IntentDialog(stringLiteral: spoken)) {
            StartWorkoutSnippetView(workout: workout, status: .sent)
        }
    }

    // MARK: - Template resolution

    /// Maps an entity back to the underlying `WorkoutTemplate`. Built-in
    /// presets short-circuit the DB; only user templates need a read.
    private func resolveTemplate(for entity: WorkoutTemplateEntity) throws -> WorkoutTemplate {
        if let preset = WorkoutPresets.all.first(where: { $0.id == entity.id }) {
            return preset
        }
        let database: any DatabaseWriter = Dependency(key: \DependencyValues.defaultDatabase).wrappedValue
        let row: WorkoutTemplate? = try database.read { db in
            try WorkoutTemplate.find(entity.id).fetchOne(db)
        }
        guard let row else {
            throw StartWorkoutIntentError.templateNotFound(name: entity.name)
        }
        return row
    }
}

// MARK: - Error

public enum StartWorkoutIntentError: LocalizedError {
    case templateNotFound(name: String)

    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let name):
            return "I couldn't find a workout named \(name) any more — it may have been deleted."
        }
    }
}
