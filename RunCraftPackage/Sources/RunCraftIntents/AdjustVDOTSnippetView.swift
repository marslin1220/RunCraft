import DesignSystem
import SwiftUI
import VDOTEngine

/// Snippet rendered after `AdjustVDOTIntent` saves. Shows the new VDOT
/// number large, then the four most-actionable pace zones underneath so
/// the runner gets immediate value from the change — no app opening
/// required.
public struct AdjustVDOTSnippetView: View {
    let vdot: Double
    let zones: PaceZones
    let paceUnit: PaceUnit
    /// If false, the runner hasn't set up a race goal yet — we surface a
    /// nudge so the recorded snapshot doesn't look like a dead-end.
    let goalExisted: Bool

    public init(
        vdot: Double,
        zones: PaceZones,
        paceUnit: PaceUnit,
        goalExisted: Bool
    ) {
        self.vdot = vdot
        self.zones = zones
        self.paceUnit = paceUnit
        self.goalExisted = goalExisted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            paceList
            if !goalExisted { warning }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("VDOT updated")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                Text("\(Int(vdot.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.brand.accent)
            }
            Spacer(minLength: 0)
        }
    }

    private var paceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(letter: "E", label: "Easy",      range: zones.easy)
            row(letter: "M", label: "Marathon",  range: zones.marathon)
            row(letter: "T", label: "Threshold", range: zones.threshold)
            row(letter: "I", label: "Interval",  range: zones.interval)
        }
    }

    private func row(letter: String, label: String, range: PaceZones.PaceRange) -> some View {
        HStack(spacing: 10) {
            Text(letter)
                .font(.caption2.bold())
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(Color.brand.accent, in: Circle())
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.brand.textPrimary)
            Spacer()
            Text(range.formatted(unit: paceUnit))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.brand.textSecondary)
        }
    }

    private var warning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.brand.caution)
            Text("Set up a race goal in RunCraft to apply this to your plan.")
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)
        }
    }
}
