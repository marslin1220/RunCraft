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
                    currentVDOTCard
                    vdotTrendCard
                    weeklyMileageCard
                    predictedRacesCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Insights")
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Cards

    @ViewBuilder
    private var currentVDOTCard: some View {
        sectionCard(title: "Current VDOT") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.currentVDOT > 0 ? "\(Int(store.currentVDOT.rounded()))" : "—")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.brand.accent)
                Text("VDOT")
                    .font(.headline)
                    .foregroundStyle(Color.brand.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var vdotTrendCard: some View {
        sectionCard(title: "VDOT trend") {
            if store.snapshots.count < 2 {
                emptyState("Not enough history yet — log a race or finish a few hard sessions.")
            } else {
                Chart(store.snapshots) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.recordedAt),
                        y: .value("VDOT", snapshot.vdot)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.brand.accent)

                    // Encode the snapshot source on TWO channels — colour and
                    // symbol — so the legend below + the symbol shape work
                    // for colour-blind users (skill rule `color-not-only`).
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
        }
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
