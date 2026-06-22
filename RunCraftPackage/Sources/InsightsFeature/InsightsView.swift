#if os(iOS)
import Charts
import ComposableArchitecture
import DesignSystem
import HealthKitClient
import RunCraftModels
import SwiftUI
import VDOTEngine

public struct InsightsView: View {
    @SwiftUI.Bindable public var store: StoreOf<InsightsFeature>

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
                    hrvTrendCard
                    heartRateRecoveryCard
                    restingHRTrendCard
                    runningEconomyCard
                    trainingZonesCard
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
        .task { await store.send(.onAppear).finish() }
        .sheet(item: $activeInfoPresentation) { presentation in
            InfoSheet(info: presentation.primary, siblings: presentation.siblings)
        }
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
    private var selectedTrendInfo: InsightInfo {
        switch store.selectedTrend {
        case .vdot:      .vdot
        case .vo2Max:    .vo2Max
        case .delta:     .delta
        case .threshold: .threshold
        }
    }

    @ViewBuilder
    private var fitnessTrendCard: some View {
        sectionCard(title: "Fitness trend", info: selectedTrendInfo,
                    siblings: [.vdot, .vo2Max, .delta, .threshold]) {
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
        case .threshold:
            if store.thresholdSeries.count < 2 {
                emptyState("Not enough VDOT history yet — log a race or finish a hard session to build your trend.")
            } else {
                thresholdChart
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

    // MARK: - Info state (shared across all cards)

    @State private var activeInfoPresentation: InsightInfoPresentation? = nil

    // MARK: - HRV trend card

    @ViewBuilder
    private var hrvTrendCard: some View {
        sectionCard(title: "Heart rate variability · 90 days", info: .hrv) {
            VStack(alignment: .leading, spacing: 10) {
                if let latest = store.hrvSamples.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(latest.sdnnMs.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.brand.accent)
                        Text("ms SDNN")
                            .font(.subheadline)
                            .foregroundStyle(Color.brand.textSecondary)
                    }
                }
                if store.hrvSamples.count < 2 {
                    emptyState("HRV readings appear here after Apple Watch records overnight SDNN data. Wear your Watch to sleep for a few nights.")
                } else {
                    Chart(store.hrvSamples) { sample in
                        LineMark(
                            x: .value("Date", sample.recordedAt),
                            y: .value("ms", sample.sdnnMs)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.brand.accent.opacity(0.7))

                        PointMark(
                            x: .value("Date", sample.recordedAt),
                            y: .value("ms", sample.sdnnMs)
                        )
                        .foregroundStyle(Color.brand.accent)
                        .symbolSize(30)
                        .accessibilityLabel(sample.recordedAt.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(sample.sdnnMs.formatted(.number.precision(.fractionLength(0)))) ms SDNN")
                    }
                    .frame(height: 140)
                    .chartYAxisLabel("ms")
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }

                    Text("Higher HRV indicates better recovery and aerobic adaptation. A rising trend over weeks means your training is building fitness without excess stress.")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    // MARK: - Resting HR trend card

    @ViewBuilder
    private var restingHRTrendCard: some View {
        sectionCard(title: "Resting heart rate · 90 days", info: .restingHR) {
            VStack(alignment: .leading, spacing: 10) {
                if let latest = store.restingHRSamples.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(latest.bpm.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.brand.accent)
                        Text("bpm")
                            .font(.subheadline)
                            .foregroundStyle(Color.brand.textSecondary)
                    }
                }
                if store.restingHRSamples.count < 2 {
                    emptyState("Resting heart rate appears after Apple Watch records several overnight readings.")
                } else {
                    let bpms = store.restingHRSamples.map(\.bpm)
                    let minBPM = (bpms.min() ?? 40) - 3
                    let maxBPM = (bpms.max() ?? 80) + 3
                    Chart(store.restingHRSamples) { sample in
                        LineMark(
                            x: .value("Date", sample.recordedAt),
                            y: .value("bpm", sample.bpm)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.brand.caution.opacity(0.7))

                        PointMark(
                            x: .value("Date", sample.recordedAt),
                            y: .value("bpm", sample.bpm)
                        )
                        .foregroundStyle(Color.brand.caution)
                        .symbolSize(30)
                        .accessibilityLabel(sample.recordedAt.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(sample.bpm.formatted(.number.precision(.fractionLength(0)))) bpm")
                    }
                    .frame(height: 140)
                    .chartYScale(domain: minBPM...maxBPM)
                    .chartYAxisLabel("bpm")
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }

                    Text("A downward trend over months indicates improving cardiovascular efficiency. Spikes above your baseline often signal illness, overtraining, or poor sleep.")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    // MARK: - Heart rate recovery card

    @ViewBuilder
    private var heartRateRecoveryCard: some View {
        sectionCard(title: "HR recovery · 90 days", info: .heartRateRecovery) {
            VStack(alignment: .leading, spacing: 10) {
                if let latest = store.hrRecoverySamples.last {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(latest.dropBPM.formatted(.number.precision(.fractionLength(0))))
                                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.brand.accent)
                            Text("bpm")
                                .font(.subheadline)
                                .foregroundStyle(Color.brand.textSecondary)
                        }
                        Text(hrrZoneLabel(latest.dropBPM))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(hrrZoneColor(latest.dropBPM).opacity(0.85), in: Capsule())
                    }
                }
                if store.hrRecoverySamples.count < 2 {
                    emptyState("HR recovery is recorded by Apple Watch at the end of each workout. Complete a few outdoor runs to see your trend.")
                } else {
                    let drops = store.hrRecoverySamples.map(\.dropBPM)
                    let yMax = (drops.max() ?? 40) + 5
                    Chart(store.hrRecoverySamples) { sample in
                        BarMark(
                            x: .value("Date", sample.recordedAt, unit: .day),
                            y: .value("Drop", sample.dropBPM)
                        )
                        .foregroundStyle(hrrZoneColor(sample.dropBPM).opacity(0.8))
                        .cornerRadius(3)
                        .accessibilityLabel(sample.recordedAt.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(sample.dropBPM.formatted(.number.precision(.fractionLength(0)))) bpm drop")
                    }
                    .chartYScale(domain: 0...yMax)
                    .chartYAxisLabel("bpm drop")
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    .frame(height: 140)

                    Text("A 1-minute drop above 22 bpm is considered good. Elite runners often exceed 40 bpm. Consistently low values signal poor recovery or overtraining.")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    private func hrrZoneLabel(_ drop: Double) -> String {
        switch drop {
        case ..<12:  "Poor"
        case 12..<22: "Below avg"
        case 22..<40: "Good"
        default:     "Excellent"
        }
    }

    private func hrrZoneColor(_ drop: Double) -> Color {
        switch drop {
        case ..<12:  .red
        case 12..<22: .orange
        case 22..<40: Color.brand.success
        default:     Color.brand.accent
        }
    }

    // MARK: - Running economy card

    @State private var selectedFormKind: RunningFormKind = .verticalOscillation

    @ViewBuilder
    private var runningEconomyCard: some View {
        sectionCard(title: "Running economy · 90 days", info: .runningEconomy) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Metric", selection: $selectedFormKind) {
                    ForEach(RunningFormKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                let samples = selectedFormKind.samples(from: store.runningForm)

                if let latest = samples.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(selectedFormKind.format(latest.value))
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.brand.accent)
                        Text(selectedFormKind.unit)
                            .font(.subheadline)
                            .foregroundStyle(Color.brand.textSecondary)
                    }
                }

                if samples.count < 2 {
                    emptyState(selectedFormKind.emptyStateText)
                } else {
                    runningFormChart(samples: samples, kind: selectedFormKind)
                    Text(selectedFormKind.interpretationText)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func runningFormChart(samples: [DatedValue], kind: RunningFormKind) -> some View {
        let values = samples.map(\.value)
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1
        // Negate y values when lower is better so "up" = improvement without
        // creating an inverted ClosedRange (which crashes Swift's precondition).
        let sign: Double = kind.lowerIsBetter ? -1.0 : 1.0
        let domainLo = kind.lowerIsBetter ? -(rawMax * 1.05) : rawMin * 0.95
        let domainHi = kind.lowerIsBetter ? -(rawMin * 0.95) : rawMax * 1.05
        Chart(samples) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(kind.unit, sign * point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.brand.accent.opacity(0.7))
            PointMark(
                x: .value("Date", point.date),
                y: .value(kind.unit, sign * point.value)
            )
            .foregroundStyle(Color.brand.accent)
            .symbolSize(30)
            .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue("\(kind.format(point.value)) \(kind.unit)")
        }
        .chartYScale(domain: domainLo...domainHi)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(kind.format(v * sign))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .chartYAxisLabel(kind.unit)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 140)
    }

    // MARK: - Training zones card

    @ViewBuilder
    private var trainingZonesCard: some View {
        sectionCard(title: "Training zones", info: .trainingZones) {
            if store.currentVDOT == 0 {
                emptyState("Set a VDOT in the Plan tab to see your pace zones.")
            } else {
                let zones = VDOTCalculator.paceZones(vdot: store.currentVDOT)
                VStack(spacing: 8) {
                    ZoneRow(name: "Easy", range: zones.easy,       color: .blue,            paceUnit: paceUnit)
                    ZoneRow(name: "Marathon", range: zones.marathon, color: Color.brand.success, paceUnit: paceUnit)
                    ZoneRow(name: "Threshold", range: zones.threshold, color: Color.brand.accent, paceUnit: paceUnit)
                    ZoneRow(name: "Interval", range: zones.interval, color: .orange,           paceUnit: paceUnit)
                    ZoneRow(name: "Repetition", range: zones.repetition, color: .red,          paceUnit: paceUnit)
                }
                Text("Zones based on Jack Daniels' Running Formula at VDOT \(Int(store.currentVDOT.rounded())).")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var thresholdChart: some View {
        let series = store.thresholdSeries
        let values = series.map(\.value)
        let lo = (values.min() ?? 240) - 10
        let hi = (values.max() ?? 360) + 10
        Chart(series) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("s/km", -point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.brand.accent)

            PointMark(
                x: .value("Date", point.date),
                y: .value("s/km", -point.value)
            )
            .foregroundStyle(Color.brand.accent)
            .symbol(.circle)
            .symbolSize(60)
            .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(PaceFormatting.paceMinutesSeconds(secondsPerKm: point.value, unit: paceUnit))
        }
        // Negate y values so "up" = faster pace (lower s/km = better LT).
        // Displaying -point.value keeps ClosedRange valid: -hi...-lo where -hi < -lo.
        .chartYScale(domain: -hi...(-lo))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let sec = value.as(Double.self) {
                        Text(PaceFormatting.paceMinutesSeconds(secondsPerKm: -sec, unit: paceUnit))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .frame(height: 200)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }

    @ViewBuilder
    private var weeklyMileageCard: some View {
        sectionCard(title: "Weekly mileage · last 8 weeks") {
            let bars = store.weeklyMileage
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
            if store.predictedTimes.isEmpty {
                emptyState("Set a VDOT in the Plan tab to see predictions.")
            } else {
                VStack(spacing: 8) {
                    ForEach(store.predictedTimes) { race in
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
                        if race.id != store.predictedTimes.last?.id {
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
            let runs = Array(store.recentWorkouts.prefix(10))
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
    @Shared(.appStorage("paceUnit", store: .runCraftGroup)) private var paceUnit: PaceUnit = .perKilometre

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        info: InsightInfo? = nil,
        siblings: [InsightInfo] = [],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand.textSecondary)
                if let info {
                    Button {
                        activeInfoPresentation = InsightInfoPresentation(primary: info, siblings: siblings)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.brand.textSecondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Learn more about \(title)")
                }
            }
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
        case .threshold:
            return PaceFormatting.paceMinutesSeconds(secondsPerKm: value, unit: paceUnit)
        }
    }
}

// MARK: - Running form kind

enum RunningFormKind: String, CaseIterable {
    case verticalOscillation
    case groundContactTime
    case strideLength

    var label: String {
        switch self {
        case .verticalOscillation: "V. Osc"
        case .groundContactTime:   "GCT"
        case .strideLength:        "Stride"
        }
    }

    var unit: String {
        switch self {
        case .verticalOscillation: "cm"
        case .groundContactTime:   "ms"
        case .strideLength:        "m"
        }
    }

    var lowerIsBetter: Bool {
        switch self {
        case .verticalOscillation, .groundContactTime: true
        case .strideLength: false
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .verticalOscillation: value.formatted(.number.precision(.fractionLength(1)))
        case .groundContactTime:   value.formatted(.number.precision(.fractionLength(0)))
        case .strideLength:        value.formatted(.number.precision(.fractionLength(2)))
        }
    }

    func samples(from trend: RunningFormTrend) -> [DatedValue] {
        switch self {
        case .verticalOscillation: trend.verticalOscillationCm
        case .groundContactTime:   trend.groundContactTimeMs
        case .strideLength:        trend.strideLengthM
        }
    }

    var emptyStateText: String {
        "Run outdoors with your Apple Watch to record \(label) data. Appears after watchOS 10 workouts with GPS."
    }

    var interpretationText: String {
        switch self {
        case .verticalOscillation:
            "Typical range: 6–13 cm. Lower means less energy wasted bouncing vertically — a hallmark of efficient running form."
        case .groundContactTime:
            "Typical range: 160–300 ms. Shorter contact time means quicker, more elastic strides and better energy return."
        case .strideLength:
            "Longer strides at the same effort indicate improved leg power and running economy over time."
        }
    }
}

// MARK: - Insight info model

/// Carries the primary `InsightInfo` shown when a sheet opens, plus an
/// optional ordered group for step-through navigation inside the sheet.
struct InsightInfoPresentation: Identifiable {
    var id: String { primary.id }
    let primary: InsightInfo
    let siblings: [InsightInfo]

    init(primary: InsightInfo, siblings: [InsightInfo] = []) {
        self.primary = primary
        self.siblings = siblings
    }
}

struct InsightInfo: Identifiable {
    let id: String
    let title: String
    let body: String

    static let vdot = InsightInfo(
        id: "vdot",
        title: "VDOT",
        body: """
VDOT is Jack Daniels' measure of your current running fitness. Derived from your best race time or training performance, it represents the effective oxygen-utilisation rate at which you actually race.

**Why it drives your plan**

VDOT powers every pace zone and session target in RunCraft — Easy, Marathon, Threshold, Interval, and Repetition paces are all computed from this single number.

**What to look for**

• A rising VDOT over a training block confirms real fitness gains.

• A plateau for 6+ weeks despite consistent training often signals the need for a new race stimulus, more easy volume, or a recovery week.

• A sudden drop usually means the race data was an anomaly (heat, illness, pacing error) — use Adjust VDOT to correct it manually.
"""
    )

    static let vo2Max = InsightInfo(
        id: "vo2Max",
        title: "VO₂max",
        body: """
VO₂max is your Apple Watch's independent estimate of maximum oxygen uptake (mL/kg/min), derived from heart rate and GPS speed during outdoor runs.

**How it differs from VDOT**

Both use the same unit but come from different sources. VDOT is derived from actual race performances. Apple Watch VO₂max is a physiological estimate from training data — typically more conservative and updated more frequently.

**What to look for**

• A gradual upward trend over months confirms aerobic capacity is growing.

• The Watch's estimate is most accurate during easy-to-moderate outdoor runs with clean GPS and stable heart rate.

• Values typically lag VDOT by 4–8 weeks when fitness improves rapidly.
"""
    )

    static let delta = InsightInfo(
        id: "delta",
        title: "Δ (VDOT − VO₂max)",
        body: """
Delta is the difference between your VDOT and your Apple Watch's VO₂max estimate. It shows how your race-derived fitness compares to the Watch's physiological reading.

**Interpreting the value**

• **Positive Δ** — race performance implies higher fitness than the Watch estimates. Common in economical runners, or when the Watch hasn't had enough outdoor runs to update.

• **Near zero** — VDOT and Watch VO₂max are in agreement. A good sign that both data sources are consistent.

• **Negative Δ** — training has built aerobic capacity faster than race-derived VDOT reflects, or your last race was an underperformance. A good prompt to attempt a time trial.

**What to watch**

A persistently widening positive gap suggests you would benefit from more race-specific work.
"""
    )

    static let threshold = InsightInfo(
        id: "threshold",
        title: "T-pace (Lactate Threshold)",
        body: """
T-pace is your lactate threshold pace — the Daniels Threshold zone midpoint, derived from your VDOT score. It represents the fastest pace sustainable for approximately 60 minutes.

**Why track it over time**

As your VDOT improves, your T-pace becomes faster. This chart shows how your threshold has progressed across your training history — a long-term view of speed development at the most important training intensity.

**Reading the chart**

The y-axis is inverted so upward movement always means improvement: a rising line means you are running faster at threshold. Each point corresponds to one VDOT update.

**What to look for**

• Consistent upward steps after threshold-focused training blocks (tempo runs, cruise intervals).

• A flat trend despite rising VDOT suggests your aerobic base is improving but race-specific speed work may be lagging.
"""
    )

    static let hrv = InsightInfo(
        id: "hrv",
        title: "Heart Rate Variability (HRV)",
        body: """
HRV measures the millisecond variation between consecutive heartbeats using the SDNN metric. A higher, stable HRV indicates that your autonomic nervous system is well-recovered and ready for training stress.

**What to look for**

• A rising weekly trend over months means your aerobic base is adapting well.

• A sudden drop of 10–15 ms below your personal baseline is a strong signal to reduce training intensity for 1–2 days.

• Day-to-day fluctuation is normal — only sustained trends matter.

Apple Watch records HRV automatically overnight using the heart rate sensor.
"""
    )

    static let restingHR = InsightInfo(
        id: "restingHR",
        title: "Resting Heart Rate",
        body: """
Resting heart rate (RHR) is the number of times your heart beats per minute at full rest. As cardiovascular fitness improves, the heart becomes more efficient — pumping more blood per beat, so it needs to beat less often.

**What to look for**

• A gradual downward trend over weeks and months indicates improving aerobic fitness.

• A spike of 5+ bpm above your baseline after a hard training block often signals incomplete recovery, illness, or overtraining.

• Elite endurance athletes typically have RHR in the 40–55 bpm range.

Apple Watch records RHR daily using overnight heart rate data.
"""
    )

    static let heartRateRecovery = InsightInfo(
        id: "heartRateRecovery",
        title: "Heart Rate Recovery",
        body: """
Heart Rate Recovery (HRR) is the drop in heart rate during the 60 seconds immediately after a workout ends. It is one of the strongest measurable markers of cardiovascular fitness and autonomic nervous-system health.

Apple Watch measures HRR automatically after every workout and stores it as heartRateRecoveryOneMinute in HealthKit.

**Interpretation**

• **< 12 bpm** — Poor. Associated with reduced fitness and higher cardiovascular risk.

• **12–22 bpm** — Below average for recreational runners.

• **22–40 bpm** — Good. Typical of trained endurance athletes.

• **> 40 bpm** — Excellent. Elite endurance range.

**What to watch for**

• An upward trend over a training block indicates improving aerobic fitness.

• Unusually low HRR after a hard week is an early sign of overtraining or approaching illness — often appears 24–48 hours before other symptoms.

• HRR improves with consistent aerobic base training and adequate recovery.
"""
    )

    static let runningEconomy = InsightInfo(
        id: "runningEconomy",
        title: "Running Economy",
        body: """
Running economy (RE) is the energy cost of running at a given speed. Better RE means using less oxygen — and less effort — to maintain the same pace. It is a key performance predictor alongside VO₂max.

Apple Watch measures three biomechanical proxies during outdoor runs on watchOS 10+.

**Vertical Oscillation (cm)**

How much your body bounces up and down per stride. Lower is better: energy spent moving vertically doesn't propel you forward. Typical range: 6–13 cm.

**Ground Contact Time (ms)**

How long your foot stays on the ground per stride. Shorter contact time indicates a more elastic, reactive stride. Elite runners: ~160–200 ms. Recreational runners: ~250–300 ms.

**Stride Length (m)**

The distance covered per stride. Longer strides at the same heart rate indicate improved leg power and RE over time.

The Vertical Oscillation and GCT charts are inverted so upward movement always means improvement.
"""
    )

    static let trainingZones = InsightInfo(
        id: "trainingZones",
        title: "Training Zones",
        body: """
These five zones come from Jack Daniels' Running Formula and are calculated directly from your VDOT score. Each targets a specific physiological adaptation.

**Easy (E)**

Aerobic base building and recovery. Comfortable enough to hold a conversation. The majority of your weekly volume belongs here.

**Marathon (M)**

Sustained aerobic effort at goal marathon race pace. Trains fat metabolism and running economy.

**Threshold (T)**

Lactate threshold pace — roughly your 60-minute race effort. Improves the speed at which your body clears lactate. Done as tempo runs or cruise intervals.

**Interval (I)**

VO₂max pace, approximately your 10–15 min race effort. Done as short hard repeats (3–5 min) with recovery jogs between.

**Repetition (R)**

Speed and economy work. Very short fast reps (60–90 sec) at close to mile race pace, with full recovery.
"""
    )
}

// MARK: - Info sheet

private struct InfoSheet: View {
    @State private var currentInfo: InsightInfo
    let siblings: [InsightInfo]
    @Environment(\.dismiss) private var dismiss

    init(info: InsightInfo, siblings: [InsightInfo] = []) {
        self._currentInfo = State(initialValue: info)
        self.siblings = siblings
    }

    private var currentIndex: Int {
        siblings.firstIndex(where: { $0.id == currentInfo.id }) ?? 0
    }
    private var hasSiblings: Bool { siblings.count > 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if hasSiblings {
                        stepBar
                            .padding(.bottom, 20)
                    }

                    Text(currentInfo.title)
                        .font(.title2.bold())
                        .foregroundStyle(Color.brand.textPrimary)
                        .padding(.bottom, 20)
                        .animation(.none, value: currentInfo.id)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(paragraphs(from: currentInfo.body), id: \.self) { para in
                            infoParagraph(para)
                        }
                    }
                    .id(currentInfo.id)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .animation(.easeInOut(duration: 0.2), value: currentInfo.id)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color.brand.background)
        }
        .presentationDetents([.medium, .large])
    }

    // Prev / label pills / next
    private var stepBar: some View {
        HStack(spacing: 8) {
            Button {
                guard currentIndex > 0 else { return }
                currentInfo = siblings[currentIndex - 1]
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(currentIndex > 0 ? Color.brand.accent : Color.brand.textSecondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(siblings) { sibling in
                        Button {
                            currentInfo = sibling
                        } label: {
                            Text(sibling.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(sibling.id == currentInfo.id ? .black : Color.brand.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(sibling.id == currentInfo.id ? Color.brand.accent : Color.brand.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                guard currentIndex < siblings.count - 1 else { return }
                currentInfo = siblings[currentIndex + 1]
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(currentIndex < siblings.count - 1 ? Color.brand.accent : Color.brand.textSecondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next")
        }
    }

    private func paragraphs(from body: String) -> [String] {
        body.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    @ViewBuilder
    private func infoParagraph(_ para: String) -> some View {
        let isBullet  = para.hasPrefix("•")
        let isHeading = !isBullet && para.hasPrefix("**")
        let attr = (try? AttributedString(markdown: para)) ?? AttributedString(para)

        Text(attr)
            .font(isHeading ? .subheadline.weight(.semibold) : .callout)
            .foregroundStyle(isHeading ? Color.brand.textPrimary : Color.brand.textSecondary)
            .padding(.leading, isBullet ? 4 : 0)
            .padding(.top, isHeading ? 16 : 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Zone row

private struct ZoneRow: View {
    let name: String
    let range: PaceZones.PaceRange
    let color: Color
    let paceUnit: PaceUnit

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.brand.textPrimary)
                Text(range.formatted(unit: paceUnit))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.brand.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) zone: \(range.formatted(unit: paceUnit))")
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
#endif
