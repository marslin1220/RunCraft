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
                    ltThresholdsCard
                    runningHistoryCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(Text("Insights", bundle: .module))
            .background(
                LinearGradient(
                    colors: [Color.brand.accent.opacity(0.07), Color.brand.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
        sectionCard(title: String(localized: "Set up your fitness baseline", bundle: .module)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set up your VDOT to unlock pace zones, training paces, and race predictions. We can detect it from Apple Health, or you can enter a recent race time.", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(Color.brand.textSecondary)

                Button {
                    store.send(.setUpVDOTTapped)
                } label: {
                    Text("Set Up VDOT", bundle: .module)
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
        sectionCard(title: String(localized: "Fitness trend", bundle: .module), info: selectedTrendInfo,
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
                emptyState(String(localized: "Not enough history yet — log a race or finish a few hard sessions.", bundle: .module))
            } else {
                vdotChart
            }
        case .vo2Max:
            if store.vo2MaxSamples.count < 2 {
                emptyState(String(localized: "Apple Watch hasn't recorded enough VO₂max samples yet. They appear after outdoor runs with strong GPS + heart-rate signal.", bundle: .module))
            } else {
                vo2MaxChart
            }
        case .delta:
            if store.deltaSeries.count < 2 {
                emptyState(String(localized: "Need both VDOT history and VO₂max samples to compute the gap.", bundle: .module))
            } else {
                deltaChart
            }
        case .threshold:
            if store.thresholdSeries.count < 2 {
                emptyState(String(localized: "Not enough VDOT history yet — log a race or finish a hard session to build your trend.", bundle: .module))
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
        sectionCard(title: String(localized: "Heart rate variability · 90 days", bundle: .module), info: .hrv) {
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
                    emptyState(String(localized: "HRV readings appear here after Apple Watch records overnight SDNN data. Wear your Watch to sleep for a few nights.", bundle: .module))
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

                    Text("Higher HRV indicates better recovery and aerobic adaptation. A rising trend over weeks means your training is building fitness without excess stress.", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    // MARK: - Resting HR trend card

    @ViewBuilder
    private var restingHRTrendCard: some View {
        sectionCard(title: String(localized: "Resting heart rate · 90 days", bundle: .module), info: .restingHR) {
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
                    emptyState(String(localized: "Resting heart rate appears after Apple Watch records several overnight readings.", bundle: .module))
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

                    Text("A downward trend over months indicates improving cardiovascular efficiency. Spikes above your baseline often signal illness, overtraining, or poor sleep.", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    // MARK: - Heart rate recovery card

    @ViewBuilder
    private var heartRateRecoveryCard: some View {
        sectionCard(title: String(localized: "HR recovery · 90 days", bundle: .module), info: .heartRateRecovery) {
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
                    emptyState(String(localized: "HR recovery is recorded by Apple Watch at the end of each workout. Complete a few outdoor runs to see your trend.", bundle: .module))
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

                    Text("A 1-minute drop above 22 bpm is considered good. Elite runners often exceed 40 bpm. Consistently low values signal poor recovery or overtraining.", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    private func hrrZoneLabel(_ drop: Double) -> String {
        switch drop {
        case ..<12:  String(localized: "Poor", bundle: .module)
        case 12..<22: String(localized: "Below avg", bundle: .module)
        case 22..<40: String(localized: "Good", bundle: .module)
        default:     String(localized: "Excellent", bundle: .module)
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

    private var selectedFormKindInfo: InsightInfo {
        switch selectedFormKind {
        case .verticalOscillation: .verticalOscillation
        case .groundContactTime:   .groundContactTime
        case .strideLength:        .strideLength
        }
    }

    @ViewBuilder
    private var runningEconomyCard: some View {
        sectionCard(title: String(localized: "Running economy · 90 days", bundle: .module), info: selectedFormKindInfo,
                    siblings: [.verticalOscillation, .groundContactTime, .strideLength]) {
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
        sectionCard(title: String(localized: "Training zones", bundle: .module), info: .trainingZones) {
            if store.currentVDOT == 0 {
                emptyState(String(localized: "Set a VDOT in the Plan tab to see your pace zones.", bundle: .module))
            } else {
                let zones = VDOTCalculator.paceZones(vdot: store.currentVDOT)
                VStack(spacing: 8) {
                    ZoneRow(name: String(localized: "Easy", bundle: .module), range: zones.easy,       color: .blue,            paceUnit: paceUnit)
                    ZoneRow(name: String(localized: "Marathon", bundle: .module), range: zones.marathon, color: Color.brand.success, paceUnit: paceUnit)
                    ZoneRow(name: String(localized: "Threshold", bundle: .module), range: zones.threshold, color: Color.brand.accent, paceUnit: paceUnit)
                    ZoneRow(name: String(localized: "Interval", bundle: .module), range: zones.interval, color: .orange,           paceUnit: paceUnit)
                    ZoneRow(name: String(localized: "Repetition", bundle: .module), range: zones.repetition, color: .red,          paceUnit: paceUnit)
                }
                Text("Zones based on Jack Daniels' Running Formula at VDOT \(Int(store.currentVDOT.rounded())).", bundle: .module)
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
        sectionCard(title: String(localized: "Weekly mileage · last 8 weeks", bundle: .module)) {
            let bars = store.weeklyMileage
            if bars.allSatisfy({ $0.totalKm == 0 }) {
                emptyState(String(localized: "No completed runs yet. They'll appear here after HealthKit syncs.", bundle: .module))
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
        sectionCard(title: String(localized: "Predicted race times", bundle: .module)) {
            if store.predictedTimes.isEmpty {
                emptyState(String(localized: "Set a VDOT in the Plan tab to see predictions.", bundle: .module))
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

    // MARK: - Lactate thresholds card

    @ViewBuilder
    private var ltThresholdsCard: some View {
        sectionCard(title: String(localized: "Lactate thresholds", bundle: .module), info: .ltThresholds) {
            if store.currentVDOT == 0 {
                emptyState(String(localized: "Set a VDOT in the Plan tab to see your threshold paces.", bundle: .module))
            } else {
                let zones = VDOTCalculator.paceZones(vdot: store.currentVDOT)
                let lt1SecPerKm = zones.easy.lower
                let lt2SecPerKm = (zones.threshold.lower + zones.threshold.upper) / 2
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LT1 · Aerobic", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(Color.brand.textSecondary)
                            Text(
                                PaceFormatting.paceMinutesSeconds(secondsPerKm: lt1SecPerKm, unit: paceUnit)
                                    + " " + paceUnit.displayName
                            )
                            .font(.system(.title3, design: .monospaced).weight(.medium))
                            .foregroundStyle(.blue)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("LT2 · Anaerobic", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(Color.brand.textSecondary)
                            Text(
                                PaceFormatting.paceMinutesSeconds(secondsPerKm: lt2SecPerKm, unit: paceUnit)
                                    + " " + paceUnit.displayName
                            )
                            .font(.system(.title3, design: .monospaced).weight(.medium))
                            .foregroundStyle(Color.brand.accent)
                        }
                    }
                    Text("LT1 is the top of your aerobic zone — the pace at which lactate begins to rise above baseline. LT2 is your anaerobic threshold, approximately your 60-minute race pace.", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }
        }
    }

    /// Running history card: week + month volume totals, 3 most-recent
    /// compact run rows, and a "View all" button that hands off to the
    /// Workouts / History segment.
    @ViewBuilder
    private var runningHistoryCard: some View {
        sectionCard(title: String(localized: "Running history", bundle: .module)) {
            VStack(spacing: 0) {
                // Week / month volume totals
                HStack(spacing: 0) {
                    volumeColumn(
                        label: String(localized: "This week", bundle: .module),
                        km: store.thisWeekKm,
                        count: store.thisWeekCount
                    )
                    Divider().frame(height: 44).padding(.horizontal, 4)
                    volumeColumn(
                        label: String(localized: "This month", bundle: .module),
                        km: store.thisMonthKm,
                        count: store.thisMonthCount
                    )
                }
                .padding(.bottom, 12)

                Divider().opacity(0.2)

                // 3 most-recent runs
                let recent = Array(store.recentWorkouts.prefix(3))
                if recent.isEmpty {
                    Text("No completed runs yet. They'll appear here after HealthKit syncs or after you log a run by voice.", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(Color.brand.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(recent) { run in
                            InsightsRunRow(run: run, paceUnit: paceUnit)
                            if run.id != recent.last?.id {
                                Divider().opacity(0.2).padding(.leading, 52)
                            }
                        }
                    }
                }

                Divider().opacity(0.2)

                // "View all runs" action
                Button {
                    store.send(.switchToHistoryTapped)
                } label: {
                    HStack(spacing: 4) {
                        Spacer()
                        Text("View all runs", bundle: .module)
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Color.brand.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func volumeColumn(label: String, km: Double, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.brand.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", km))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.brand.textPrimary)
                Text("km")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.brand.textSecondary)
            }
            Text(String(format: String(localized: "%lld runs", bundle: .module), count))
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .glassCard(cornerRadius: 12)
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
    let title: LocalizedStringResource
    let body: LocalizedStringResource

    static let vdot = InsightInfo(
        id: "vdot",
        title: LocalizedStringResource("InsightInfo.vdot.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.vdot.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let vo2Max = InsightInfo(
        id: "vo2Max",
        title: LocalizedStringResource("InsightInfo.vo2Max.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.vo2Max.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let delta = InsightInfo(
        id: "delta",
        title: LocalizedStringResource("InsightInfo.delta.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.delta.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let threshold = InsightInfo(
        id: "threshold",
        title: LocalizedStringResource("InsightInfo.threshold.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.threshold.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let hrv = InsightInfo(
        id: "hrv",
        title: LocalizedStringResource("InsightInfo.hrv.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.hrv.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let restingHR = InsightInfo(
        id: "restingHR",
        title: LocalizedStringResource("InsightInfo.restingHR.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.restingHR.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let heartRateRecovery = InsightInfo(
        id: "heartRateRecovery",
        title: LocalizedStringResource("InsightInfo.heartRateRecovery.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.heartRateRecovery.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let verticalOscillation = InsightInfo(
        id: "verticalOscillation",
        title: LocalizedStringResource("InsightInfo.verticalOscillation.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.verticalOscillation.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let groundContactTime = InsightInfo(
        id: "groundContactTime",
        title: LocalizedStringResource("InsightInfo.groundContactTime.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.groundContactTime.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let strideLength = InsightInfo(
        id: "strideLength",
        title: LocalizedStringResource("InsightInfo.strideLength.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.strideLength.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let ltThresholds = InsightInfo(
        id: "ltThresholds",
        title: LocalizedStringResource("InsightInfo.ltThresholds.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.ltThresholds.body", bundle: .atURL(Bundle.module.bundleURL))
    )

    static let trainingZones = InsightInfo(
        id: "trainingZones",
        title: LocalizedStringResource("InsightInfo.trainingZones.title", bundle: .atURL(Bundle.module.bundleURL)),
        body: LocalizedStringResource("InsightInfo.trainingZones.body", bundle: .atURL(Bundle.module.bundleURL))
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
                        ForEach(paragraphs(from: String(localized: currentInfo.body)), id: \.self) { para in
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
                    Button { dismiss() } label: { Text("Done", bundle: .module) }
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

/// Compact run row used in the Insights running-history card.
/// Shows session-type icon, session name, date, and the big distance number.
private struct InsightsRunRow: View {
    let run: CompletedWorkout
    let paceUnit: PaceUnit

    private var distanceKm: Double { run.actualDistanceKm }

    private var distanceFormatted: String {
        String(format: "%.2f", paceUnit == .perKilometre ? distanceKm : distanceKm * 0.621371)
    }

    private var distanceUnit: String { paceUnit == .perKilometre ? "km" : "mi" }

    private var paceText: String {
        PaceFormatting.paceMinutesSeconds(secondsPerKm: run.avgPaceSecPerKm, unit: paceUnit)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.run")
                .font(.body)
                .foregroundStyle(Color.brand.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(run.completedAt, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(distanceFormatted)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.brand.textPrimary)
                    Text(distanceUnit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.brand.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Text(paceText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.brand.textSecondary)
        }
        .padding(.vertical, 8)
    }
}
#endif
