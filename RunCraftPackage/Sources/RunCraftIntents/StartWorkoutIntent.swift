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
/// row), writes the payload to WCSession application context, and calls
/// `HKHealthStore.startWatchApp(toHandle:)` via `HKWatchTriggerClient` to
/// auto-launch `RunCraftWatch` and begin the structured workout on the wrist.
public struct StartWorkoutIntent: AppIntent {

    public static let title: LocalizedStringResource = "Start a workout"

    public static let description = IntentDescription(
        "Auto-start a RunCraft workout on your paired Apple Watch.",
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

        let hkWatchTriggerClient: HKWatchTriggerClient = Dependencies.Dependency(\.hkWatchTriggerClient).wrappedValue

        do {
            try await hkWatchTriggerClient.startWatchSession(
                WatchWorkoutPayload(name: template.name, blocks: template.blocks)
            )
        } catch {
            let name = workout.name
            let errorMsg = error.localizedDescription
            return .result(
                dialog: IntentDialog(stringLiteral: String(
                    localized: "I couldn't send \(name) to your Watch. \(errorMsg)",
                    bundle: .module
                ))
            ) {
                StartWorkoutSnippetView(workout: workout, status: .failed)
            }
        }

        let name = workout.name
        let spoken = String(localized: "Starting \(name) on your Apple Watch.", bundle: .module)
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
        let database: any DatabaseWriter = Dependencies.Dependency(\.defaultDatabase).wrappedValue
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
            return String(localized: "I couldn't find a workout named \(name) any more — it may have been deleted.", bundle: .module)
        }
    }
}
