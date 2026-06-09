import SwiftUI

/// Two-wheel picker for entering a duration as minutes + seconds. Shared
/// across forms so the time-entry UX stays consistent (Workshop edit-step
/// sheet, race-goal setup, etc.).
///
/// Bindings are independent `Int` values (not a single `TimeInterval`) so
/// the host can persist whatever shape it prefers.
public struct TimeWheelPicker: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    let minutesRange: ClosedRange<Int>

    public init(
        minutes: Binding<Int>,
        seconds: Binding<Int>,
        minutesRange: ClosedRange<Int> = 0...180
    ) {
        self._minutes = minutes
        self._seconds = seconds
        self.minutesRange = minutesRange
    }

    public var body: some View {
        HStack(spacing: 0) {
            Picker("min", selection: $minutes) {
                ForEach(minutesRange, id: \.self) { Text("\($0)").tag($0) }
            }
            .labelsHidden()
            #if os(iOS)
            .pickerStyle(.wheel)
            #endif
            .frame(maxWidth: .infinity)

            Text("min")
                .foregroundStyle(.secondary)
                .frame(width: 40)

            Picker("sec", selection: $seconds) {
                ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .labelsHidden()
            #if os(iOS)
            .pickerStyle(.wheel)
            #endif
            .frame(maxWidth: .infinity)

            Text("sec")
                .foregroundStyle(.secondary)
                .frame(width: 40)
        }
        .frame(height: 120)
    }
}
