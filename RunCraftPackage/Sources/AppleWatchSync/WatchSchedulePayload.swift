import Foundation
import RunCraftModels

/// Watch-side summary of the current week's training plan, pushed from iPhone
/// via `updateApplicationContext["schedule"]` whenever the plan loads.
///
/// The iPhone pre-builds every `WatchWorkoutPayload` so the Watch never needs
/// VDOTEngine or PlanSessionAdapter — it just renders and starts.
public struct WatchSchedulePayload: Codable, Sendable {

    public struct Session: Codable, Sendable, Identifiable {
        public var id: UUID
        /// Abbreviated day name, e.g. "Mon", "Wed".
        public var dayName: String
        /// Human-readable session title, e.g. "Easy Run", "Intervals".
        public var title: String
        public var sessionType: SessionType
        /// Mon=1 … Sun=7 (same encoding as `PlannedSession.dayOfWeek`).
        /// Stored in the payload so the Watch can recompute `isToday`/`isPast`
        /// at render time — avoiding stale values when the payload was sent on
        /// a previous day.
        public var dayOfWeek: Int
        public var payload: WatchWorkoutPayload

        /// Computed at render time so a cached payload is never stale.
        public var isToday: Bool { dayOfWeek == Self.currentDayOfWeek }
        /// Computed at render time so a cached payload is never stale.
        public var isPast: Bool { dayOfWeek < Self.currentDayOfWeek }

        private static var currentDayOfWeek: Int {
            PlannedSession.dayOfWeek(for: Date())
        }

        public init(
            id: UUID,
            dayName: String,
            title: String,
            sessionType: SessionType,
            dayOfWeek: Int,
            payload: WatchWorkoutPayload
        ) {
            self.id = id
            self.dayName = dayName
            self.title = title
            self.sessionType = sessionType
            self.dayOfWeek = dayOfWeek
            self.payload = payload
        }
    }

    /// Non-rest sessions for the current training week, sorted Mon → Sun.
    public var sessions: [Session]
    /// Pace-zone quick-start templates (Easy · 30 min, Threshold · 30 min, …).
    public var paceTemplates: [WatchWorkoutPayload]

    public init(sessions: [Session], paceTemplates: [WatchWorkoutPayload]) {
        self.sessions = sessions
        self.paceTemplates = paceTemplates
    }
}
