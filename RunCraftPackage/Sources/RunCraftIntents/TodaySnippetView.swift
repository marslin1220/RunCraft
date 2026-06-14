import DesignSystem
import RunCraftModels
import SwiftUI
import VDOTEngine

/// Snippet view rendered inline in Siri / Spotlight / Apple Intelligence
/// when the runner asks "what's today's training?". Static, no buttons —
/// interactive snippets (with embedded intents) ship in a later phase.
public struct TodaySnippetView: View {
    let entity: TodaySessionEntity?
    let paceUnit: PaceUnit

    public init(entity: TodaySessionEntity?, paceUnit: PaceUnit) {
        self.entity = entity
        self.paceUnit = paceUnit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entity {
                header(for: entity)
                metricsRow(for: entity)
                if let zone = entity.paceZone,
                   let lo = entity.paceLowerSecPerKm,
                   let hi = entity.paceUpperSecPerKm {
                    paceRow(zone: zone, range: PaceZones.PaceRange(lower: lo, upper: hi))
                }
            } else {
                emptyState
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func header(for entity: TodaySessionEntity) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entity.sessionType.symbolName)
                .font(.title3)
                .foregroundStyle(Color.brand.accent)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's training")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                Text(entity.sessionTitle)
                    .font(.title3.bold())
                    .foregroundStyle(Color.brand.textPrimary)
            }
        }
    }

    @ViewBuilder
    private func metricsRow(for entity: TodaySessionEntity) -> some View {
        HStack(spacing: 18) {
            if let km = entity.targetDistanceKm {
                metric(value: distanceText(km: km), label: distanceLabel)
            }
            if let minutes = entity.targetDurationMin {
                metric(value: "\(minutes)", label: "min")
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.brand.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.brand.textSecondary)
        }
    }

    private func paceRow(zone: PaceZoneName, range: PaceZones.PaceRange) -> some View {
        HStack(spacing: 8) {
            Text(zone.letter)
                .font(.caption.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.brand.accent, in: Capsule())
            Text(range.formatted(unit: paceUnit))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.brand.textPrimary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No plan yet")
                .font(.headline)
                .foregroundStyle(Color.brand.textPrimary)
            Text("Open RunCraft and set up a race goal to generate a training plan.")
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)
        }
    }

    private func distanceText(km: Double) -> String {
        PaceFormatting.distanceValue(metres: km * 1_000, unit: paceUnit)
            .formatted(.number.precision(.fractionLength(0...1)))
    }

    private var distanceLabel: String {
        paceUnit.distanceSuffix
    }
}
