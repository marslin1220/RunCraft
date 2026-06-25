import ComposableArchitecture
import DesignSystem
import InsightsFeature
import SwiftUI
import TrainingPlanFeature
import VDOTEngine
import WorkshopFeature

public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>
    /// Hides the first-launch onboarding flow forever once dismissed.
    /// Plain `@AppStorage` (same pattern as the pace-unit picker in
    /// Settings) so the flag persists without going through TCA state.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("appearanceOverride", store: .runCraftGroup) private var appearanceOverrideRaw: String = AppearanceOverride.auto.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var resolvedColorScheme: ColorScheme? {
        (AppearanceOverride(rawValue: appearanceOverrideRaw) ?? .auto).colorScheme
    }

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            PlanView(store: store.scope(state: \.plan, action: \.plan))
                .tabItem {
                    Label { Text("Plan", bundle: .module) } icon: { Image(systemName: "calendar") }
                }
                .tag(AppFeature.Tab.plan)

            WorkshopView(store: store.scope(state: \.workouts, action: \.workouts))
                .tabItem {
                    Label { Text("Workouts", bundle: .module) } icon: { Image(systemName: "figure.run") }
                }
                .tag(AppFeature.Tab.workouts)

            InsightsView(store: store.scope(state: \.insights, action: \.insights))
                .tabItem {
                    Label { Text("Insights", bundle: .module) } icon: { Image(systemName: "chart.line.uptrend.xyaxis") }
                }
                .tag(AppFeature.Tab.insights)

            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Label { Text("Settings", bundle: .module) } icon: { Image(systemName: "gearshape") }
                }
                .tag(AppFeature.Tab.settings)
        }
        .tint(Color.brand.accent)
        .preferredColorScheme(resolvedColorScheme)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.send(.plan(.watchScheduleSync))
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { _ in /* dismissal handled via onComplete */ }
        )) {
            OnboardingView(onComplete: {
                hasCompletedOnboarding = true
                // Land on the Plan tab — that's where the SetupRaceGoal
                // prompt lives. Onboarding ends with "let's build your
                // first plan," so we want the runner to see it.
                store.send(.tabSelected(.plan))
            })
        }
        #if os(iOS)
        .task { await store.send(.onTask).finish() }
        .fullScreenCover(
            isPresented: Binding(
                get: { store.liveWorkout != nil },
                set: { _ in }
            )
        ) {
            if let display = store.liveWorkout {
                LiveWorkoutView(store: store, display: display)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { store.completionSummary != nil },
                set: { if !$0 { store.send(.dismissCompletionSummary) } }
            )
        ) {
            if let summary = store.completionSummary {
                WorkoutCompletionView(summary: summary) {
                    store.send(.dismissCompletionSummary)
                }
            }
        }
        #endif
    }
}

