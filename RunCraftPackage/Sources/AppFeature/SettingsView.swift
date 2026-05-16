import ComposableArchitecture
import SwiftUI

public struct SettingsView: View {
    @Bindable public var store: StoreOf<Settings>

    public init(store: StoreOf<Settings>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Pace", selection: $store.paceUnit) {
                        ForEach(Settings.State.PaceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Connections") {
                    HStack {
                        Label("HealthKit", systemImage: "heart.fill")
                        Spacer()
                        if store.isHealthKitLinked {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Link") {
                                store.send(.linkHealthKitTapped)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.8, green: 1.0, blue: 0.0))
                            .foregroundStyle(.black)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(.dark)
            .onAppear { store.send(.onAppear) }
        }
    }
}
