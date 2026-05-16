import ComposableArchitecture
import SwiftUI
import TrainingPlanFeature

public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            PlanView(store: store.scope(state: \.plan, action: \.plan))
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(AppFeature.Tab.plan)

            WorkshopPlaceholderView()
                .tabItem {
                    Label("Workshop", systemImage: "wrench.and.screwdriver")
                }
                .tag(AppFeature.Tab.workshop)

            InsightsPlaceholderView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppFeature.Tab.insights)

            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppFeature.Tab.settings)
        }
        .tint(Color(red: 0.8, green: 1.0, blue: 0.0))   // #CCFF00 Electric Lime
        .preferredColorScheme(.dark)
    }
}

// MARK: - Placeholder views for P1 tabs

private struct WorkshopPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Workshop")
                .font(.title2).bold()
            Text("Drag-and-drop workout editor — coming in Phase 2")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

private struct InsightsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Insights")
                .font(.title2).bold()
            Text("VDOT trend charts and predicted race times — coming in Phase 2")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
