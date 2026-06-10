import Charts
import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SwiftUI

public struct InsightsView: View {
    @Bindable public var store: StoreOf<InsightsFeature>

    public init(store: StoreOf<InsightsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    fitnessTrendCard
                    weeklyMileageCard
                    predictedRacesCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Insights")
            .background(Color.brand.background)
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Cards

    /// VDOT / VO₂max / Δ in one card. Segmented picker at the top because
    /// the three series are *peers* — discoverable side-by-side beats a
    /// swipe gesture that hides options. Hero value + caption explain
    /// what's selected; chart below visualises the trend.
    @ViewBuilder
    private var fitnessTrendCard: some View {
        sectionCard(title: "Fitness trend") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Series", selection: $store.selectedTrend) {
                    ForEach(InsightsFeature.TrendKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                heroRow

                trendChart
            }
        }
    }

    @ViewBuilder
    private var heroRow: some View {
        // `.center` rather than `.firstTextBaseline` here — the rounded
        // 44pt digit has a huge ascender that makes baseline-alignment
        // look top-heavy. Centring the big number against the two-line
        // caption block keeps the visual weight balanced.
        HStack(alignment: .center, spacing: 10) {
            Text(heroValueText)
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.brand.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedTrend.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand.textPrimary)
                Text(store.selectedTrend.caption)
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var trendChart: some View {
        switch store.selectedTrend {
        case .vdot:
            if store.snapshots.count < 2 {
                emptyState("Not enough history yet — log a race or finish a few hard sessions.")
            } else {
                vdotChart
            }
        case .vo2Max:
            if store.vo2MaxSamples.count < 2 {
                emptyState("Apple Watch hasn't recorded enough VO₂max samples yet. They appear after outdoor runs with strong GPS + heart-rate signal.")
            } else {
                vo2MaxChart
            }
        case .delta:
            if store.deltaSeries.count < 2 {
                emptyState("Need both VDOT history and VO₂max samples to compute the gap.")
            } else {
                deltaChart
            }
        }
    }

    @ViewBuilder
    private var vdotChart: some View {
        Chart(store.snapshots) { snapshot in
            LineMark(
                x: .value("Date", snapshot.recordedAt),
                y: .value("VDOT", snapshot.vdot)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.brand.accent)

            // Encode the snapshot source on TWO channels — colour and
            // symbol — so the legend + symbol shapes work for colour-blind
            // users (skill rule `color-not-only`).
            PointMark(
                x: .value("Date", snapshot.recordedAt),
                y: .value("VDOT", snapshot.vdot)
            )
            .foregroundStyle(by: .value("Source", snapshot.source.legendLabel))
            .symbol(by: .value("Source", snapshot.source.legendLabel))
            .symbolSize(80)
            .accessibilityLabel("\(snapshot.source.legendLabel) update on \(snapshot.recordedAt.formatted(date: .abbreviated, time: .omitted))")
            .accessibilityValue("VDOT \(snapshot.vdot.formatted(.number.precision(.fractionLength(1))))")
        }
        .chartForegroundStyleScale([
            VDOTSnapshot.Source.initial.legendLabel:         .blue,
            VDOTSnapshot.Source.raceTime.legendLabel:        Color.brand.accent,
            VDOTSnapshot.Source.overperformance.legendLabel: Color.brand.success,
            VDOTSnapshot.Source.manual.legendLabel:          Color.brand.caution,
        ])
        .chartSymbolScale([
            VDOTSnapshot.Source.initial.legendLabel:         .circle,
            VDOTSnapshot.Source.raceTime.legendLabel:        .square,
            VDOTSnapshot.Source.overperformance.legendLabel: .diamond,
            VDOTSnapshot.Source.manual.legendLabel:          .triangle,
        ])
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
        .frame(height: 200)
        .chartYScale(domain: vdotYDomain)
        .chartYAxisLabel("VDOT")
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }

    @ViewBuilder
    private var vo2MaxChart: some View {
        Chart(store.vo2MaxSamples) { sample in
            LineMark(
                x: .value("Date", sample.recordedAt),
                y: .value("VO₂max", sample.vo2Max)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.brand.accent)

            PointMark(
                x: .value("Date", sample.recordedAt),
                y: .value("VO₂max", sample.vo2Max)
            )
            .foregroundStyle(Color.brand.accent)
            .symbol(.circle)
            .symbolSize(50)
            .accessibilityLabel("VO2max on \(sample.recordedAt.formatted(date: .abbreviated, time: .omitted))")
            .accessibilityValue("\(sample.vo2Max.formatted(.number.precision(.fractionLength(1))))")
        }
        .frame(height: 200)
        .chartYScale(domain: vo2MaxYDomain)
        .chartYAxisLabel("VO₂max")
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }

    @ViewBuilder
    private var deltaChart: some View {
        Chart(store.deltaSeries) { point in
            // Zero baseline so positive/negative regions read at a glance.
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.brand.textSecondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))

            LineMark(
                x: .value("Date", point.date),
                y: .value("Δ", point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(point.value >= 0 ? Color.brand.success : Color.brand.caution)

            PointMark(
                x: .value("Date", point.date),
                y: .value("Δ", point.value)
            )
            .foregroundStyle(point.value >= 0 ? Color.brand.success : Color.brand.caution)
            .symbol(.circle)
            .symbolSize(50)
            .accessibilityLabel("Delta on \(point.date.formatted(date: .abbreviated, time: .omitted))")
            .accessibilityValue("\(point.value.formatted(.number.precision(.fractionLength(1))))")
        }
        .frame(height: 200)
        .chartYAxisLabel("Δ")
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }

    @ViewBuilder
    private var weeklyMileageCard: some View {
        sectionCard(title: "Weekly mileage · last 8 weeks") {
            let bars = store.state.weeklyMileage
            if bars.allSatisfy({ $0.totalKm == 0 }) {
                emptyState("No completed runs yet. They'll appear here after HealthKit syncs.")
            } else {
                Chart(bars) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("km", week.totalKm)
                    )
                    .foregroundStyle(Color.brand.accent.opacity(0.85))
                    .cornerRadius(4)
                    .accessibilityLabel("Week of \(week.weekStart.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityValue("\(week.totalKm.formatted(.number.precision(.fractionLength(0...1)))) kilometres")
                }
                .frame(height: 160)
                .chartYAxisLabel("km")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var predictedRacesCard: some View {
        sectionCard(title: "Predicted race times") {
            if store.state.predictedTimes.isEmpty {
                emptyState("Set a VDOT in the Plan tab to see predictions.")
            } else {
                VStack(spacing: 8) {
                    ForEach(store.state.predictedTimes) { race in
                        HStack {
                            Text(race.distance.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text(race.formatted)
                                .font(.system(.title3, design: .monospaced).weight(.medium))
                                .foregroundStyle(Color.brand.accent)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(race.distance.displayName) predicted time \(race.formatted)")
                        if race.id != store.state.predictedTimes.last?.id {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brand.textSecondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brand.surface)
        )
    }

    @ViewBuilder
    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.brand.textSecondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }

    private var vdotYDomain: ClosedRange<Double> {
        let values = store.snapshots.map(\.vdot)
        guard let min = values.min(), let max = values.max() else { return 30...85 }
        // Pad ±2 so the line isn't clipped at edges.
        return (min - 2)...(max + 2)
    }

    private var vo2MaxYDomain: ClosedRange<Double> {
        let values = store.vo2MaxSamples.map(\.vo2Max)
        guard let min = values.min(), let max = values.max() else { return 30...70 }
        return (min - 2)...(max + 2)
    }

    /// Hero number for the currently selected trend. `—` placeholder when
    /// the underlying series is empty (e.g. no VO₂max from the Watch yet).
    private var heroValueText: String {
        guard let value = store.heroValue else { return "—" }
        switch store.selectedTrend {
        case .vdot:
            return "\(Int(value.rounded()))"
        case .vo2Max:
            return value.formatted(.number.precision(.fractionLength(1)))
        case .delta:
            let prefix = value > 0 ? "+" : ""
            return "\(prefix)\(value.formatted(.number.precision(.fractionLength(1))))"
        }
    }
}

private extension VDOTSnapshot.Source {
    /// User-facing name for the chart legend + VoiceOver labels.
    var legendLabel: String {
        switch self {
        case .initial:         "Initial"
        case .raceTime:        "Race time"
        case .overperformance: "Workout"
        case .manual:          "Manual"
        }
    }
}
