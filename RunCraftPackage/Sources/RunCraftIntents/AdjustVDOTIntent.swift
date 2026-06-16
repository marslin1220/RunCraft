import AppIntents
import Dependencies
import Foundation
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine

/// "Set my VDOT to 52 in RunCraft" — voice-driven manual calibration.
///
/// Same write path as `AdjustVDOTFeature`: bumps `RaceGoal.currentVDOT`
/// and inserts a `VDOTSnapshot` with source `.manual` so the Insights
/// trend chart picks it up. Read-only on the goal row if no goal exists
/// yet — the snapshot still gets recorded.
public struct AdjustVDOTIntent: AppIntent {

    public static let title: LocalizedStringResource = "Set VDOT"

    public static let description = IntentDescription(
        "Manually adjust the VDOT that RunCraft uses to compute pace zones.",
        categoryName: "Training"
    )

    /// The intent doesn't need to bring up the app — the change is purely
    /// data-side and the snippet view reports the new paces.
    public static let openAppWhenRun: Bool = false

    @Parameter(
        title: "VDOT",
        description: "Daniels' VDOT score. Typically 30 (beginner) to 85 (elite).",
        inclusiveRange: (30, 85)
    )
    public var vdot: Double

    public init() {}

    public init(vdot: Double) {
        self.vdot = vdot
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let database: any DatabaseWriter = Dependencies.Dependency(\.defaultDatabase).wrappedValue

        let clamped = max(30, min(85, vdot))
        let snapshot = VDOTSnapshot(vdot: clamped, recordedAt: Date(), source: .manual)

        let goalExisted: Bool = try await database.write { db in
            let existed = (try RaceGoal.fetchCount(db)) > 0
            if existed {
                try RaceGoal.update { $0.currentVDOT = clamped }.execute(db)
            }
            try VDOTSnapshot.upsert { snapshot }.execute(db)
            return existed
        }

        let zones = VDOTCalculator.paceZones(vdot: clamped)
        let unit = PaceUnit.current
        let easy = zones.easy.formatted(unit: unit)
        let threshold = zones.threshold.formatted(unit: unit)

        let spoken: String
        if goalExisted {
            spoken = "VDOT set to \(Int(clamped.rounded())). Easy pace is now \(easy), threshold \(threshold)."
        } else {
            spoken = "Recorded VDOT \(Int(clamped.rounded())), but you don't have a race goal yet. Set one up in RunCraft to see the new plan."
        }

        return .result(dialog: IntentDialog(stringLiteral: spoken)) {
            AdjustVDOTSnippetView(
                vdot: clamped,
                zones: zones,
                paceUnit: unit,
                goalExisted: goalExisted
            )
        }
    }
}
