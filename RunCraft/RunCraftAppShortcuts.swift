import AppFeature
import AppIntents

/// Registers RunCraft's voice phrases with the system. iOS scans for this
/// type at install time and surfaces the phrases in Siri, Spotlight, the
/// Shortcuts app, and Apple Intelligence.
///
/// Phase 1 ships a single read-only intent. Phase 2 adds "Start <template>"
/// with a parameter, which will appear here alongside.
struct RunCraftAppShortcuts: AppShortcutsProvider {

    /// Marketing tint shown next to the shortcut in the Shortcuts app and
    /// when the suggestion bubbles up via Spotlight.
    static let shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatIsTodaysTrainingIntent(),
            phrases: [
                "What's today's training in \(.applicationName)",
                "What's today's \(.applicationName) training",
                "\(.applicationName) today's session",
                "Show today's run in \(.applicationName)",
            ],
            shortTitle: "Today's Training",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start \(\.$workout) in \(.applicationName)",
                "Start \(\.$workout) workout in \(.applicationName)",
                "Send \(\.$workout) to my Watch in \(.applicationName)",
                "Run \(\.$workout) in \(.applicationName)",
            ],
            shortTitle: "Start Workout",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: AdjustVDOTIntent(),
            phrases: [
                "Set my VDOT to \(\.$vdot) in \(.applicationName)",
                "Update \(.applicationName) VDOT to \(\.$vdot)",
                "Adjust \(.applicationName) VDOT to \(\.$vdot)",
            ],
            shortTitle: "Set VDOT",
            systemImageName: "speedometer"
        )
        AppShortcut(
            intent: LogCompletedRunIntent(),
            phrases: [
                "Log a run in \(.applicationName)",
                "Log a completed run in \(.applicationName)",
                "Record a run in \(.applicationName)",
            ],
            shortTitle: "Log Run",
            systemImageName: "figure.run.square.stack"
        )
    }
}
