import ComposableArchitecture
import DesignSystem
import SwiftUI

/// 7-day toggle row + optional long-run-day picker, shared by
/// `SetupRaceGoalView` (initial setup / edit) and `AdjustTrainingDaysView`
/// (standalone mid-plan sheet).
public struct TrainingDaysGrid: View {
    @Bindable public var store: StoreOf<TrainingDaysInput>

    public init(store: StoreOf<TrainingDaysInput>) {
        self.store = store
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                dayToggle(day)
            }
        }
        .padding(.vertical, 4)

        // TrainingPlanGenerator ignores `longRunDay` in maintenance mode
        // (availableDays.count < 2), so hide the picker there.
        if store.availableDays.count >= 2 {
            Picker("Long run day", selection: $store.longRunDay) {
                Text("No preference").tag(nil as Int?)
                ForEach(store.availableDays.sorted(), id: \.self) { day in
                    Text(weekdayLabel(day)).tag(day as Int?)
                }
            }
        }
    }

    private func dayToggle(_ day: Int) -> some View {
        let isSelected = store.availableDays.contains(day)
        return Button {
            store.send(.dayToggled(day))
        } label: {
            Text(weekdayLabel(day))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.brand.textSecondary)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.brand.accent : Color.brand.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
