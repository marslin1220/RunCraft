import ComposableArchitecture
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

    public init(store: StoreOf<Settings>) {
        self.store = store
    }

    private var paceUnit: Binding<PaceUnit> {
        Binding(
            get: { PaceUnit(rawValue: paceUnitRaw) ?? .perKilometre },
            set: { paceUnitRaw = $0.rawValue }
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
}
