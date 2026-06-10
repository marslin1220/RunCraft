import AppIntents
import Foundation
import RunCraftModels
import VDOTEngine

/// Intent-facing projection of "today's planned session" — flattened so
/// Siri / Spotlight / Apple Intelligence can render it without knowing
/// about the underlying SQLiteData schema.
///
/// Singleton: there is only one "today," so `id` is the literal "today".
/// This lets `TodaySessionQuery` return at most one entity.
public struct TodaySessionEntity: AppEntity {

    public static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: "Today's Training Session")

    public static let defaultQuery = TodaySessionQuery()

    public let id: String
    public let sessionType: SessionType
    public let sessionTitle: String
    public let targetDistanceKm: Double?
    public let targetDurationMin: Int?
    public let paceZone: PaceZoneName?
    public let paceLowerSecPerKm: Double?
    public let paceUpperSecPerKm: Double?

    public init(
        id: String,
        sessionType: SessionType,
        sessionTitle: String,
        targetDistanceKm: Double?,
        targetDurationMin: Int?,
        paceZone: PaceZoneName?,
        paceLowerSecPerKm: Double?,
        paceUpperSecPerKm: Double?
    ) {
        self.id = id
        self.sessionType = sessionType
        self.sessionTitle = sessionTitle
        self.targetDistanceKm = targetDistanceKm
        self.targetDurationMin = targetDurationMin
        self.paceZone = paceZone
        self.paceLowerSecPerKm = paceLowerSecPerKm
        self.paceUpperSecPerKm = paceUpperSecPerKm
    }

    public var displayRepresentation: DisplayRepresentation {
        var parts: [String] = []
        if let km = targetDistanceKm {
            parts.append("\(km.formatted(.number.precision(.fractionLength(0...1)))) km")
        }
        if let minutes = targetDurationMin {
            parts.append("\(minutes) min")
        }
        if let zone = paceZone {
            parts.append("\(zone.letter) pace")
        }
        return DisplayRepresentation(
            title: "\(sessionTitle)",
            subtitle: parts.isEmpty ? nil : "\(parts.joined(separator: " · "))"
        )
    }
}
