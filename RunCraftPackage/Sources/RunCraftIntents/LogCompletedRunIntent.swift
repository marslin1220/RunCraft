import AppIntents
import Dependencies
import Foundation
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine

/// "Log a 5 km run in 25 minutes in RunCraft" — voice-driven activity log
/// for runners who tracked outside HealthKit (treadmill, lent watch, etc.).
///
/// Writes a `CompletedWorkout` row with no `plannedSessionId` /
/// `hkWorkoutId`, and a neutral `paceAchievementRatio` of 1 — the runner
/// can compare against plan from the Insights tab.
public struct LogCompletedRunIntent: AppIntent {

    public static let title: LocalizedStringResource = "Log a completed run"

    public static let description = IntentDescription(
        "Save a run you finished without HealthKit tracking. Records distance, duration and average pace.",
        categoryName: "Training"
    )

    public static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Distance",
        description: "How far you ran, in kilometres.",
        controlStyle: .field,
        inclusiveRange: (0.1, 100),
        requestValueDialog: "How many kilometres did you run?"
    )
    public var distanceKm: Double

    @Parameter(
        title: "Duration",
        description: "How long the run took, in minutes.",
        controlStyle: .field,
        inclusiveRange: (1, 600),
        requestValueDialog: "How many minutes did it take?"
    )
    public var durationMin: Int

    public init() {}

    public init(distanceKm: Double, durationMin: Int) {
        self.distanceKm = distanceKm
        self.durationMin = durationMin
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let database: any DatabaseWriter = Dependencies.Dependency(\.defaultDatabase).wrappedValue

        let km = max(0.1, distanceKm)
        let seconds = Double(max(1, durationMin)) * 60
        let avgPaceSecPerKm = seconds / km

        let workout = CompletedWorkout(
            completedAt: Date(),
            actualDistanceKm: km,
            actualDurationSec: seconds,
            avgPaceSecPerKm: avgPaceSecPerKm,
            paceAchievementRatio: 1.0
        )

        try await database.write { db in
            try CompletedWorkout.upsert { workout }.execute(db)
        }

        let unit = PaceUnit.current
        let spoken = Self.spokenSummary(km: km, seconds: seconds, unit: unit)

        return .result(dialog: IntentDialog(stringLiteral: spoken)) {
            LogCompletedRunSnippetView(
                distanceKm: km,
                durationSec: seconds,
                avgPaceSecPerKm: avgPaceSecPerKm,
                paceUnit: unit
            )
        }
    }

    // MARK: - Helpers

    /// "Logged a 5.0 kilometre run in 25 minutes. Average pace 5:00 per kilometre."
    /// Locale-respecting: switches to miles if the runner has chosen mi/hr in Settings.
    static func spokenSummary(km: Double, seconds: Double, unit: PaceUnit) -> String {
        let distanceValue = PaceFormatting.distanceValue(metres: km * 1_000, unit: unit)
        let distanceLabel: String
        let paceSuffix: String
        switch unit {
        case .perKilometre:
            distanceLabel = abs(distanceValue - 1) < 0.05 ? "kilometre" : "kilometres"
            paceSuffix = "per kilometre"
        case .perMile:
            distanceLabel = abs(distanceValue - 1) < 0.05 ? "mile" : "miles"
            paceSuffix = "per mile"
        }
        let distanceText = distanceValue.formatted(.number.precision(.fractionLength(0...1)))
        let minutesText = Int((seconds / 60).rounded())
        let paceText = PaceFormatting.paceMinutesSeconds(secondsPerKm: seconds / km, unit: unit)
        return "Logged a \(distanceText) \(distanceLabel) run in \(minutesText) minutes. Average pace \(paceText) \(paceSuffix)."
    }
}
