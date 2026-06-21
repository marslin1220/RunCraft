#if os(iOS)
import DesignSystem
import SwiftUI
import VDOTEngine

struct WorkoutCompletionView: View {
    let summary: AppFeature.CompletionSummary
    let onDismiss: () -> Void
    @AppStorage("paceUnit", store: .runCraftGroup) private var paceUnitRaw: String = PaceUnit.perKilometre.rawValue

    private var paceUnit: PaceUnit {
        PaceUnit(rawValue: paceUnitRaw) ?? .perKilometre
    }

    private var distanceText: String {
        PaceFormatting.distance(metres: summary.totalMetres, unit: paceUnit)
    }

    private var elapsedText: String {
        let s = summary.elapsedSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private var avgPaceText: String {
        guard summary.avgPaceSecPerKm > 0 else { return "--:--" }
        return PaceFormatting.paceMinutesSeconds(secondsPerKm: summary.avgPaceSecPerKm, unit: paceUnit)
    }

    var body: some View {
        VStack(spacing: 28) {
            header
            metricsGrid
            Spacer(minLength: 0)
            Button("Done", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(Color.brand.accent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brand.accent)
            Text("Workout Complete")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.brand.textPrimary)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            CompletionTile(label: "Distance", value: distanceText, unit: "")
            CompletionTile(label: "Time", value: elapsedText, unit: "")
            CompletionTile(
                label: "Avg Pace",
                value: avgPaceText,
                unit: paceUnit.displayName
            )
            if summary.avgHeartRate > 0 {
                CompletionTile(
                    label: "Avg HR",
                    value: "\(Int(summary.avgHeartRate))",
                    unit: "bpm"
                )
            }
        }
    }
}

private struct CompletionTile: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !unit.isEmpty {
                Text(verbatim: unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        WorkoutCompletionView(
            summary: AppFeature.CompletionSummary(
                totalMetres: 5240,
                elapsedSeconds: 1638,
                avgPaceSecPerKm: 312,
                avgHeartRate: 158
            ),
            onDismiss: {}
        )
    }
}
#endif
