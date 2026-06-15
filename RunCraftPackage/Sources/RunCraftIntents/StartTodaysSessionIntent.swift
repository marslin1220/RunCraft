import AppIntents
import AppleWatchSync
import Dependencies
import Foundation
import RunCraftModels
import SQLiteData

/// "Start today's RunCraft session" — sends today's planned session to the
/// paired Apple Watch without opening the app. Backs the tap-to-start
/// action on the Today's-session widget, and mirrors
/// `TrainingPlanFeature.quickStartSession`'s
/// `PlanSessionAdapter.makeTemplate(from:vdot:)` →
/// `workoutKitClient.openInWorkoutApp(template)` flow.
public struct StartTodaysSessionIntent: AppIntent {

    public static let title: LocalizedStringResource = "Start today's session"

    public static let description = IntentDescription(
        "Send today's planned RunCraft session to your paired Apple Watch.",
        categoryName: "Training"
    )

    /// Stays out of the app — the value of this intent is bypassing the
    /// UI to get straight to the run. The Watch is the destination, not
    /// the iPhone screen.
    public static let openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let database: any DatabaseWriter = Dependency(key: \DependencyValues.defaultDatabase).wrappedValue
        let today = try await database.read { db in try TodaysSession.current(in: db) }

        guard let today, today.session.sessionType != .rest else {
            return .result(dialog: "There's no training session scheduled for today.")
        }

        let workoutKitClient: WorkoutKitClient = Dependency(key: \DependencyValues.workoutKitClient).wrappedValue
        let template = PlanSessionAdapter.makeTemplate(from: today.session, vdot: today.vdot)
        try await workoutKitClient.openInWorkoutApp(template)

        return .result(dialog: "Sending \(today.session.sessionType.displayName) to your Apple Watch.")
    }
}
