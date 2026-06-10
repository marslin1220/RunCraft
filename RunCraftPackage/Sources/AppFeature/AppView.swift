import ComposableArchitecture
import DesignSystem
import InsightsFeature
import SwiftUI
import TrainingPlanFeature
import WorkshopFeature

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

            WorkshopView(store: store.scope(state: \.workouts, action: \.workouts))
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
                .tag(AppFeature.Tab.workouts)

            InsightsView(store: store.scope(state: \.insights, action: \.insights))
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
        .tint(Color.brand.accent)
    }
}

