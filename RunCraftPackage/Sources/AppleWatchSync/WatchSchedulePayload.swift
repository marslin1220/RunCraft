import Foundation

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
        public var isToday: Bool
        public var payload: WatchWorkoutPayload

        public init(
            id: UUID,
            dayName: String,
            title: String,
            isToday: Bool,
            payload: WatchWorkoutPayload
        ) {
            self.id = id
            self.dayName = dayName
            self.title = title
            self.isToday = isToday
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
