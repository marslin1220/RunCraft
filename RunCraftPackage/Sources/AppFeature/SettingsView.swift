import ComposableArchitecture
import Dependencies
import DesignSystem
import SwiftUI
import VDOTEngine

public struct SettingsView: View {
    @Bindable public var store: StoreOf<Settings>
    /// Pace unit lives in UserDefaults; Settings is the writer, every other
    /// view reads via @Shared(.appStorage("paceUnit")). Using @AppStorage
    /// here (instead of routing through the Settings state) sidesteps the
    /// BindingReducer + @Shared edge cases that were causing toggles to
    /// silently drop.
    @AppStorage("paceUnit") private var paceUnitRaw: String = PaceUnit.perKilometre.rawValue

    /// Daily training reminder. Persisted as three keys so the toggle and
    /// the time picker stay independent of each other — same @AppStorage
    /// pattern as the pace unit (sidesteps the BindingReducer + @Shared
    /// quirks).
    @AppStorage("notifications.reminderEnabled") private var reminderEnabled: Bool = false
    @AppStorage("notifications.reminderHour")   private var reminderHour: Int = 7
    @AppStorage("notifications.reminderMinute") private var reminderMinute: Int = 0

    public init(store: StoreOf<Settings>) {
        self.store = store
    }

    private var paceUnit: Binding<PaceUnit> {
        Binding(
            get: { PaceUnit(rawValue: paceUnitRaw) ?? .perKilometre },
            set: { paceUnitRaw = $0.rawValue }
        )
    }

    /// Combined hour + minute as a Date for the SwiftUI DatePicker —
    /// the picker round-trips through Date even though we persist the
    /// individual components.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: reminderHour, minute: reminderMinute)
                ) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour   = comps.hour   ?? 7
                reminderMinute = comps.minute ?? 0
                rescheduleReminderIfEnabled()
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Pace", selection: paceUnit) {
                        ForEach(PaceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Daily training reminder", isOn: Binding(
                        get: { reminderEnabled },
                        set: { newValue in
                            reminderEnabled = newValue
                            Task { await applyReminderState(enabled: newValue) }
                        }
                    ))
                    if reminderEnabled {
                        DatePicker(
                            "Time",
                            selection: reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Daily nudge at the time you pick. Tap to open RunCraft and dispatch today's session to Apple Watch.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Link(destination: URL(string: "https://vdoto2.com")!) {
                        Label("About Jack Daniels VDOT", systemImage: "info.circle.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Reminder side effects

    /// Reconciles the system schedule with the toggle. Called on flip and
    /// from the time picker so changes take effect without an app restart.
    @MainActor
    private func applyReminderState(enabled: Bool) async {
        @Dependency(\.notificationsService) var service
        if enabled {
            let granted = (try? await service.requestAuthorization()) ?? false
            guard granted else {
                // User denied — flip the toggle back so the UI is honest.
                reminderEnabled = false
                return
            }
            try? await service.scheduleDailyReminder(
                DateComponents(hour: reminderHour, minute: reminderMinute)
            )
        } else {
            await service.cancelScheduled()
        }
    }

    /// Re-fires the schedule when the time changes while enabled. Cheap to
    /// call repeatedly — UNUserNotificationCenter replaces by identifier.
    private func rescheduleReminderIfEnabled() {
        guard reminderEnabled else { return }
        Task { @MainActor in
            @Dependency(\.notificationsService) var service
            try? await service.scheduleDailyReminder(
                DateComponents(hour: reminderHour, minute: reminderMinute)
            )
        }
    }
}
