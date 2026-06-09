import ComposableArchitecture
import DesignSystem
import SwiftUI
import VDOTEngine

public struct SettingsView: View {
    @Bindable public var store: StoreOf<Settings>

    public init(store: StoreOf<Settings>) {
        self.store = store
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
                    Picker("Pace", selection: $store.paceUnit) {
                        ForEach(PaceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        Label("HealthKit", systemImage: "heart.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        if store.isHealthKitLinked {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.brand.success)
                                Text("Linked")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Link") {
                                store.send(.linkHealthKitTapped)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.brand.accent)
                            .foregroundStyle(.black)
                        }
                    }
                } header: {
                    Text("Connections")
                } footer: {
                    Text("RunCraft reads your running history, HRV, and sleep to detect VDOT improvements and recommend recovery days.")
                        .font(.caption)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Link(destination: URL(string: "https://github.com/anthropics/claude-code/issues")!) {
                        Label("Report a bug", systemImage: "ladybug.fill")
                    }

                    Link(destination: URL(string: "https://www.vo2maxrunning.com/vdot-calculator")!) {
                        Label("About Jack Daniels VDOT", systemImage: "info.circle.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(.dark)
            .onAppear { store.send(.onAppear) }
        }
    }
}
