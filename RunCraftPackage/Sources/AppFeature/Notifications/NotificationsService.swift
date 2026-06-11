import Dependencies
import Foundation
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` so the Settings reducer
/// can request authorization, schedule, and cancel reminders without
/// importing UserNotifications directly. Live impl talks to the real
/// system centre; test value is a noop set of closures.
///
/// We don't store dynamic per-day content (today's session paces) in
/// the notification body because daily-repeating triggers don't let us
/// update the body each fire. Instead the body is generic ("Today's
/// training is ready") and the tap opens the Plan tab where the runner
/// sees the live session card.
public struct NotificationsService: Sendable {
    /// Asks the system for alert + sound permission. Returns `true` if
    /// granted, `false` if denied or not-determined. Idempotent —
    /// re-asking after a previous grant returns true without prompting.
    public var requestAuthorization: @Sendable () async throws -> Bool

    /// Schedules a daily repeating reminder at the given local-time
    /// components (hour + minute). Cancels any prior reminder first so
    /// the schedule is single-shot in spirit (one reminder, repeating
    /// daily). Idempotent.
    public var scheduleDailyReminder: @Sendable (DateComponents) async throws -> Void

    /// Removes the scheduled daily reminder. Safe to call when nothing
    /// is scheduled.
    public var cancelScheduled: @Sendable () async -> Void

    public init(
        requestAuthorization: @escaping @Sendable () async throws -> Bool,
        scheduleDailyReminder: @escaping @Sendable (DateComponents) async throws -> Void,
        cancelScheduled: @escaping @Sendable () async -> Void
    ) {
        self.requestAuthorization = requestAuthorization
        self.scheduleDailyReminder = scheduleDailyReminder
        self.cancelScheduled = cancelScheduled
    }
}

// MARK: - DependencyKey

extension NotificationsService: DependencyKey {
    /// Identifier we always use for the daily reminder. Stable so
    /// cancel/reschedule replaces the prior schedule rather than
    /// stacking duplicates.
    static let dailyReminderID = "runcraft.daily-reminder"

    public static var liveValue: NotificationsService {
        NotificationsService(
            requestAuthorization: {
                let center = UNUserNotificationCenter.current()
                return try await center.requestAuthorization(options: [.alert, .sound])
            },
            scheduleDailyReminder: { components in
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])

                let content = UNMutableNotificationContent()
                content.title = String(
                    localized: "Today's RunCraft training is ready",
                    bundle: .module
                )
                content.body = String(
                    localized: "Open RunCraft to see your session and dispatch it to Apple Watch.",
                    bundle: .module
                )
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: true
                )
                let request = UNNotificationRequest(
                    identifier: dailyReminderID,
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
            },
            cancelScheduled: {
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
            }
        )
    }

    public static var testValue: NotificationsService {
        NotificationsService(
            requestAuthorization: { true },
            scheduleDailyReminder: { _ in },
            cancelScheduled: {}
        )
    }

    public static var previewValue: NotificationsService { testValue }
}

extension DependencyValues {
    public var notificationsService: NotificationsService {
        get { self[NotificationsService.self] }
        set { self[NotificationsService.self] = newValue }
    }
}
