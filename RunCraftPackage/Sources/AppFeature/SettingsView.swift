import ComposableArchitecture
import Dependencies
import DesignSystem
import SwiftUI
import VDOTEngine

public struct SettingsView: View {
    @Bindable public var store: StoreOf<Settings>
    /// Pace unit lives in the App Group's shared UserDefaults (`.runCraftGroup`)
    /// so the Today's-session widget can read it too; Settings is the writer,
    /// every other view reads via @Shared(.appStorage("paceUnit", store:)).
    /// Using @AppStorage here (instead of routing through the Settings state)
    /// sidesteps the BindingReducer + @Shared edge cases that were causing
    /// toggles to silently drop.
    @AppStorage("paceUnit", store: .runCraftGroup) private var paceUnitRaw: String = PaceUnit.perKilometre.rawValue
    @AppStorage("appearanceOverride", store: .runCraftGroup) private var appearanceOverrideRaw: String = AppearanceOverride.auto.rawValue

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

    private var appearanceOverride: Binding<AppearanceOverride> {
        Binding(
            get: { AppearanceOverride(rawValue: appearanceOverrideRaw) ?? .auto },
            set: { appearanceOverrideRaw = $0.rawValue }
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
                Section {
                    Picker(selection: paceUnit) {
                        ForEach(PaceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    } label: {
                        Text("Pace", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Units", bundle: .module)
                }

                Section {
                    Picker(selection: appearanceOverride) {
                        ForEach(AppearanceOverride.allCases, id: \.self) { option in
                            Text(LocalizedStringKey(option.displayName), bundle: .module).tag(option)
                        }
                    } label: {
                        Text("Theme", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance", bundle: .module)
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { reminderEnabled },
                        set: { newValue in
                            reminderEnabled = newValue
                            Task { await applyReminderState(enabled: newValue) }
                        }
                    )) {
                        Text("Daily training reminder", bundle: .module)
                    }
                    if reminderEnabled {
                        DatePicker(
                            selection: reminderTime,
                            displayedComponents: .hourAndMinute
                        ) {
                            Text("Time", bundle: .module)
                        }
                    }
                } header: {
                    Text("Notifications", bundle: .module)
                } footer: {
                    Text("Daily nudge at the time you pick. Tap to open RunCraft and dispatch today's session to Apple Watch.", bundle: .module)
                }

                Section {
                    Button {
                        store.send(.delegate(.openTrainingDays))
                    } label: {
                        Label {
                            Text("Training days", bundle: .module)
                        } icon: {
                            Image(systemName: "calendar.badge.checkmark")
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Training Plan", bundle: .module)
                } footer: {
                    Text("Choose which days of the week you can train and set your preferred long-run day.", bundle: .module)
                }

                Section {
                    HStack {
                        Text("Version", bundle: .module)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Link(destination: URL(string: "https://vdoto2.com")!) {
                        Label {
                            Text("About Jack Daniels VDOT", bundle: .module)
                        } icon: {
                            Image(systemName: "info.circle.fill")
                        }
                    }

                    Link(destination: URL(string: "https://marslin1220.github.io/RunCraft/privacy/")!) {
                        Label {
                            Text("Privacy Policy", bundle: .module)
                        } icon: {
                            Image(systemName: "lock.shield")
                        }
                    }
                } header: {
                    Text("About", bundle: .module)
                }
            }
            .navigationTitle(Text("Settings", bundle: .module))
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
