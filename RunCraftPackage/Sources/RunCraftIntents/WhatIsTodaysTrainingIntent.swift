import AppIntents
import Foundation
import RunCraftModels
import SwiftUI
import VDOTEngine

/// "What's today's RunCraft training?" — voice-friendly read intent.
///
/// Returns a spoken dialog plus a SwiftUI snippet rendered inline in Siri
/// / Spotlight / Apple Intelligence. No side effects, no UI launch.
public struct WhatIsTodaysTrainingIntent: AppIntent {

    public static let title: LocalizedStringResource = "What's today's training?"

    public static let description = IntentDescription(
        "Read the planned RunCraft session for today out loud, with target distance, duration and pace.",
        categoryName: "Training"
    )

    /// Read-only — fine to run without unlocking the device or opening the app.
    public static let openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let entity = try await TodaySessionQuery().loadToday()

        let unit = Self.readPaceUnit()

        guard let entity else {
            return .result(
                dialog: "I don't see a RunCraft plan for today. Open the app and set up a race goal to generate one."
            ) {
                TodaySnippetView(entity: nil, paceUnit: unit)
            }
        }

        let spoken = Self.spokenSummary(for: entity, unit: unit)
        return .result(dialog: IntentDialog(stringLiteral: spoken)) {
            TodaySnippetView(entity: entity, paceUnit: unit)
        }
    }

    // MARK: - Helpers

    /// Reads the runner's pace unit preference. Lives in shared UserDefaults
    /// — Settings is the writer; every other surface (PlanView, AdjustVDOT,
    /// this intent) reads.
    static func readPaceUnit() -> PaceUnit {
        let raw = UserDefaults.standard.string(forKey: "paceUnit") ?? PaceUnit.perKilometre.rawValue
        return PaceUnit(rawValue: raw) ?? .perKilometre
    }

    /// Builds the sentence Siri reads aloud. Keep it conversational and
    /// avoid acronyms — "threshold pace" reads better than "T pace."
    static func spokenSummary(for entity: TodaySessionEntity, unit: PaceUnit) -> String {
        switch entity.sessionType {
        case .rest:
            return "Today is a rest day. Stay easy."
        default:
            break
        }

        var sentence = "Today's session is \(entity.sessionTitle.lowercased())"

        if let km = entity.targetDistanceKm {
            let value: Double
            let label: String
            switch unit {
            case .perKilometre:
                value = km
                label = km == 1 ? "kilometre" : "kilometres"
            case .perMile:
                value = km / 1.609344
                label = value == 1 ? "mile" : "miles"
            }
            sentence += ", \(value.formatted(.number.precision(.fractionLength(0...1)))) \(label)"
        } else if let minutes = entity.targetDurationMin {
            sentence += ", \(minutes) minutes"
        }

        if let zone = entity.paceZone, let lo = entity.paceLowerSecPerKm, let hi = entity.paceUpperSecPerKm {
            let range = PaceZones.PaceRange(lower: lo, upper: hi)
            sentence += " at \(zone.displayName.lowercased()) pace, \(range.formatted(unit: unit))"
        }

        return sentence + "."
    }
}
