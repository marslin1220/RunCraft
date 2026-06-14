import DesignSystem
import SwiftUI
import VDOTEngine

/// Snippet rendered after `LogCompletedRunIntent` saves. Three big metrics
/// (distance / duration / pace) plus a confirmation. Same monospaced
/// numerals as the Plan tab so the runner sees a familiar layout.
public struct LogCompletedRunSnippetView: View {
    let distanceKm: Double
    let durationSec: Double
    let avgPaceSecPerKm: Double
    let paceUnit: PaceUnit

    public init(
        distanceKm: Double,
        durationSec: Double,
        avgPaceSecPerKm: Double,
        paceUnit: PaceUnit
    ) {
        self.distanceKm = distanceKm
        self.durationSec = durationSec
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.paceUnit = paceUnit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            metrics
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.brand.success)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Logged to RunCraft")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                Text("Run recorded")
                    .font(.title3.bold())
                    .foregroundStyle(Color.brand.textPrimary)
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: 20) {
            metric(value: distanceText, label: distanceLabel)
            metric(value: durationText, label: "duration")
            metric(value: paceText,     label: "pace \(paceUnit.displayName)")
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.brand.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.brand.textSecondary)
        }
    }

    private var footer: some View {
        Text("Visible in the Insights tab.")
            .font(.caption)
            .foregroundStyle(Color.brand.textSecondary)
    }

    // MARK: - Computed text

    private var distanceText: String {
        PaceFormatting.distanceValue(metres: distanceKm * 1_000, unit: paceUnit)
            .formatted(.number.precision(.fractionLength(0...1)))
    }

    private var distanceLabel: String {
        paceUnit.distanceSuffix
    }

    private var durationText: String {
        let minutes = Int(durationSec) / 60
        let seconds = Int(durationSec) % 60
        if seconds == 0 { return "\(minutes) min" }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private var paceText: String {
        PaceFormatting.paceMinutesSeconds(secondsPerKm: avgPaceSecPerKm, unit: paceUnit)
    }
}
