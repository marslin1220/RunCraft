import Charts
import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SwiftUI
import VDOTEngine

public struct InsightsView: View {
    @Bindable public var store: StoreOf<InsightsFeature>

    public init(store: StoreOf<InsightsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.currentVDOT == 0 {
                        vdotSetupCard
                    }
                    fitnessTrendCard
                    weeklyMileageCard
                    predictedRacesCard
                    recentRunsCard
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

    /// Shown in place of real data when there's no VDOT yet — every other
    /// card on this screen renders an empty state in that case, so this is
    /// the one actionable thing the runner can do here.
    @ViewBuilder
    private var vdotSetupCard: some View {
        sectionCard(title: "Set up your fitness baseline") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set up your VDOT to unlock pace zones, training paces, and race predictions. We can detect it from Apple Health, or you can enter a recent race time.")
                    .font(.footnote)
                    .foregroundStyle(Color.brand.textSecondary)

                Button {
                    store.send(.setUpVDOTTapped)
                } label: {
                    Text("Set Up VDOT")
                        .bold()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.brand.accent)
                        .clipShape(Capsule())
                }
            }
        }
    }

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

    /// Last ten completed runs. Each row reads as a single sentence —
    /// date, distance, duration, average pace — so the runner can scan
    /// the column. A small arrow ↑/↓ next to the pace flags whether the
    /// run beat or missed the target session pace (when linked to one).
    @ViewBuilder
    private var recentRunsCard: some View {
        sectionCard(title: "Recent runs") {
            let runs = Array(store.state.recentWorkouts.prefix(10))
            if runs.isEmpty {
                emptyState("No completed runs yet. They'll appear here after HealthKit syncs or after you log a run by voice.")
            } else {
                VStack(spacing: 10) {
                    ForEach(runs) { run in
                        RecentRunRow(run: run, paceUnit: paceUnit)
                        if run.id != runs.last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
    }

    /// Pace-unit preference written by Settings. Reading at view scope
    /// (not from store) so the row updates instantly when the runner
    /// flips km/mi.
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

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

/// One row in the Recent Runs list. Three monospaced metrics + a date —
/// designed to read as a single line on iPhone widths, wrap gracefully
/// on Dynamic Type up to xxxLarge.
///
/// `paceAchievementRatio` interpretation: `< 1.0` means the runner was
/// faster than the planned pace. We surface that as an upward arrow on
/// the pace column; symmetric ↓ for "slower than planned." No icon if
/// the run wasn't linked to a planned session.
private struct RecentRunRow: View {
    let run: CompletedWorkout
    let paceUnit: PaceUnit

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var distanceText: String {
        PaceFormatting.distance(metres: run.actualDistanceKm * 1_000, unit: paceUnit)
    }

    private var durationText: String {
        let totalSeconds = Int(run.actualDurationSec)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes))"
        }
        return PaceFormatting.minutesSeconds(run.actualDurationSec)
    }

    private var paceText: String {
        PaceFormatting.paceMinutesSeconds(secondsPerKm: run.avgPaceSecPerKm, unit: paceUnit)
    }

    private var achievementIcon: (symbol: String, color: Color)? {
        guard run.plannedSessionId != nil else { return nil }
        if run.paceAchievementRatio < 0.95 {
            return ("arrow.up", Color.brand.success)
        }
        if run.paceAchievementRatio > 1.05 {
            return ("arrow.down", Color.brand.caution)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: run.completedAt))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.brand.textPrimary)
                Text(distanceText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.brand.textSecondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if let achievement = achievementIcon {
                        Image(systemName: achievement.symbol)
                            .font(.caption.bold())
                            .foregroundStyle(achievement.color)
                            .accessibilityHidden(true)
                    }
                    Text(paceText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.brand.textPrimary)
                    Text(paceUnit == .perKilometre ? "/km" : "/mi")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.brand.textSecondary)
                }
                Text(durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.brand.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Self.dateFormatter.string(from: run.completedAt)), \(distanceText), \(durationText), pace \(paceText) \(paceUnit == .perKilometre ? "per kilometre" : "per mile")")
    }
}
