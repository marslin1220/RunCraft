// ScreenshotPreviews.swift
// Standalone hardcoded mock views for App Store screenshot generation.
// Not compiled in release builds — wrap with #if DEBUG if needed.

import Charts
import SwiftUI

// MARK: - Shared helpers (inline — no local package imports)

private let black   = Color.black
private let surface = Color(red: 0.10, green: 0.10, blue: 0.18)
private let accent  = Color(red: 0.00, green: 0.831, blue: 1.00)   // #00D4FF
private let textPri = Color.white
private let textSec = Color(white: 0.74)

private struct PaceChip: View {
    let letter: String
    let range: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Text(letter)
                .font(.caption2.bold())
                .foregroundStyle(color)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(color.opacity(0.18), in: Capsule())
            Text(range)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(textSec)
        }
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote.bold())
            .foregroundStyle(textSec)
            .padding(.horizontal, 16)
    }
}

// MARK: - Screenshot 1: Plan tab — Week 9 of 16, today = Tuesday Interval

private struct PlanScreenshot: View {

    private struct MockSession: Identifiable {
        let id = UUID()
        let day: String
        let type: String
        let symbol: String
        let color: Color
        let distance: String?
        let paceZone: String?
        let paceRange: String?
        let isToday: Bool
        let isRest: Bool
    }

    private let sessions: [MockSession] = [
        .init(day: "Mon", type: "Rest",         symbol: "moon.zzz",          color: Color(white: 0.5),                        distance: nil,      paceZone: nil, paceRange: nil,              isToday: false, isRest: true),
        .init(day: "Tue", type: "Interval Run", symbol: "flame",             color: Color(red: 0.96, green: 0.26, blue: 0.21), distance: "10 km",  paceZone: "I", paceRange: "4:45–5:05 /km", isToday: true,  isRest: false),
        .init(day: "Wed", type: "Easy Run",     symbol: "figure.run",        color: Color(red: 0.30, green: 0.69, blue: 0.31), distance: "8 km",   paceZone: "E", paceRange: "6:00–6:30 /km", isToday: false, isRest: false),
        .init(day: "Thu", type: "Rest",         symbol: "moon.zzz",          color: Color(white: 0.5),                        distance: nil,      paceZone: nil, paceRange: nil,              isToday: false, isRest: true),
        .init(day: "Fri", type: "Tempo Run",    symbol: "bolt",              color: Color(red: 1.00, green: 0.76, blue: 0.03), distance: "10 km",  paceZone: "T", paceRange: "5:20–5:35 /km", isToday: false, isRest: false),
        .init(day: "Sat", type: "Easy Run",     symbol: "figure.run",        color: Color(red: 0.30, green: 0.69, blue: 0.31), distance: "6 km",   paceZone: "E", paceRange: "6:00–6:30 /km", isToday: false, isRest: false),
        .init(day: "Sun", type: "Long Run",     symbol: "figure.run.circle", color: Color(red: 0.40, green: 0.49, blue: 0.92), distance: "26 km",  paceZone: "E", paceRange: "6:00–6:30 /km", isToday: false, isRest: false),
    ]

    var body: some View {
        ZStack {
            black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Nav bar
                    HStack {
                        Text("Plan")
                            .font(.largeTitle.bold())
                            .foregroundStyle(textPri)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "speedometer")
                                .font(.caption.bold())
                                .foregroundStyle(black)
                            Text("VDOT 52")
                                .font(.subheadline.bold())
                                .foregroundStyle(black)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(accent, in: Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Race goal banner
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(accent)
                        Text("Taipei Marathon · Nov 23")
                            .font(.subheadline)
                            .foregroundStyle(textPri)
                        Spacer()
                        Text("18 weeks")
                            .font(.caption.bold())
                            .foregroundStyle(accent)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16).padding(.bottom, 16)

                    // Week header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Week 9 of 16")
                                .font(.headline)
                                .foregroundStyle(textPri)
                            Text("Build phase · 62 km this week")
                                .font(.caption)
                                .foregroundStyle(textSec)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("3/7 done")
                                .font(.caption.bold())
                                .foregroundStyle(textSec)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 10)

                    // Session cards
                    VStack(spacing: 8) {
                        ForEach(sessions) { s in
                            if s.isRest {
                                restRow(s)
                            } else {
                                sessionCard(s)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func sessionCard(_ s: MockSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: s.symbol)
                .font(.title2)
                .foregroundStyle(s.color)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(s.day) · \(s.type)")
                    .font(.headline)
                    .foregroundStyle(textPri)
                if let d = s.distance {
                    Text(d)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(textSec)
                }
                if let zone = s.paceZone, let range = s.paceRange {
                    PaceChip(letter: zone, range: range, color: s.color)
                }
            }
            Spacer()
            if s.isToday {
                ZStack {
                    Circle().fill(s.color).frame(width: 44, height: 44)
                    Image(systemName: "play.fill")
                        .font(.callout.bold()).foregroundStyle(.black)
                        .offset(x: 1)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold()).foregroundStyle(textSec)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(s.isToday ? s.color.opacity(0.18) : surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(s.isToday ? s.color.opacity(0.45) : s.color.opacity(0.12), lineWidth: 1)
        )
    }

    private func restRow(_ s: MockSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: s.symbol)
                .font(.subheadline)
                .foregroundStyle(textSec)
                .frame(width: 32, height: 32)
            Text("\(s.day) · Rest")
                .font(.subheadline)
                .foregroundStyle(textSec)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .opacity(0.7)
    }
}

// MARK: - Screenshot 2: Insights — VDOT trend + race predictions

private struct InsightsScreenshot: View {

    private struct VDOTPoint: Identifiable {
        let id = UUID()
        let week: Int
        let vdot: Double
    }

    private let trend: [VDOTPoint] = [
        .init(week: 1,  vdot: 49.5),
        .init(week: 2,  vdot: 49.8),
        .init(week: 3,  vdot: 50.2),
        .init(week: 4,  vdot: 50.0),
        .init(week: 5,  vdot: 50.8),
        .init(week: 6,  vdot: 51.3),
        .init(week: 7,  vdot: 51.7),
        .init(week: 8,  vdot: 52.1),
        .init(week: 9,  vdot: 52.4),
    ]

    var body: some View {
        ZStack {
            black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Nav
                    Text("Insights")
                        .font(.largeTitle.bold())
                        .foregroundStyle(textPri)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // VDOT trend card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("VDOT")
                                    .font(.caption.bold())
                                    .foregroundStyle(textSec)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("52.4")
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(textPri)
                                    Text("+2.9 this plan")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                        .padding(.bottom, 4)
                                }
                            }
                            Spacer()
                            Picker("", selection: .constant(0)) {
                                Text("VDOT").tag(0)
                                Text("VO₂max").tag(1)
                                Text("T-pace").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 170)
                        }

                        Chart(trend) { pt in
                            LineMark(
                                x: .value("Week", pt.week),
                                y: .value("VDOT", pt.vdot)
                            )
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            AreaMark(
                                x: .value("Week", pt.week),
                                yStart: .value("Base", 48.5),
                                yEnd: .value("VDOT", pt.vdot)
                            )
                            .foregroundStyle(accent.opacity(0.12))
                            PointMark(
                                x: .value("Week", trend.last!.week),
                                y: .value("VDOT", trend.last!.vdot)
                            )
                            .foregroundStyle(accent)
                            .symbolSize(60)
                        }
                        .chartYScale(domain: 48...55)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [49, 51, 53]) { v in
                                AxisValueLabel {
                                    Text("\(v.as(Int.self) ?? 0)")
                                        .font(.caption2).foregroundStyle(textSec)
                                }
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(Color.white.opacity(0.1))
                            }
                        }
                        .frame(height: 130)
                    }
                    .padding(16)
                    .background(surface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // Race predictions card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Race Predictions")
                            .font(.headline).foregroundStyle(textPri)
                        HStack(spacing: 0) {
                            ForEach([("5K","18:42"),("10K","38:56"),("½M","1:26:04"),("M","3:00:53")], id: \.0) { dist, time in
                                VStack(spacing: 4) {
                                    Text(dist)
                                        .font(.caption.bold()).foregroundStyle(textSec)
                                    Text(time)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(textPri)
                                }
                                .frame(maxWidth: .infinity)
                                if dist != "M" {
                                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 34)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(surface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // LT1 / LT2 card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lactate Threshold")
                            .font(.headline).foregroundStyle(textPri)
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LT1 — Aerobic")
                                    .font(.caption).foregroundStyle(textSec)
                                Text("5:58 /km")
                                    .font(.title3.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.green)
                                Text("147 bpm")
                                    .font(.caption.monospacedDigit()).foregroundStyle(textSec)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 50)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LT2 — Anaerobic")
                                    .font(.caption).foregroundStyle(textSec)
                                Text("5:22 /km")
                                    .font(.title3.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Color(red: 1, green: 0.76, blue: 0.03))
                                Text("163 bpm")
                                    .font(.caption.monospacedDigit()).foregroundStyle(textSec)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .background(surface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // HRV card (partially visible)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HRV Trend")
                            .font(.headline).foregroundStyle(textPri)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("62")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(textPri)
                            Text("ms")
                                .font(.subheadline).foregroundStyle(textSec)
                            Spacer()
                            Text("+8 ms this month")
                                .font(.caption).foregroundStyle(.green)
                        }
                    }
                    .padding(16)
                    .background(surface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Screenshot 3: Live Activity — lock screen during interval workout

private struct LiveActivityScreenshot: View {
    var body: some View {
        ZStack {
            // Lock screen wallpaper simulation
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.08, green: 0.03, blue: 0.12)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Status bar area
                Spacer().frame(height: 60)

                // Lock screen time
                VStack(spacing: 4) {
                    Text("8:47")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(.white)
                    Text("Monday, June 16")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer().frame(height: 40)

                // Live Activity card
                VStack(spacing: 10) {
                    // Top row: step + elapsed
                    HStack {
                        Label("Rep 3/5 · Run", systemImage: "figure.run")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                        Spacer()
                        Text("18:24")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }

                    // Progress bar
                    VStack(spacing: 3) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.2))
                                Capsule().fill(Color.green)
                                    .frame(width: g.size.width * 0.65)
                            }
                        }
                        .frame(height: 4)
                        HStack {
                            Spacer()
                            Text("Goal: 1000 m")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Metrics row
                    HStack(spacing: 0) {
                        // HR
                        VStack(spacing: 2) {
                            Text("HR")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("164")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.red).monospacedDigit()
                                Text("bpm").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            Text("Z4")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.orange, in: Capsule())
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 34)

                        // Pace
                        VStack(spacing: 2) {
                            Text("Pace")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("4:52")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.green).monospacedDigit()
                                Text("/km").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            Text("4:59 avg")
                                .font(.system(size: 9)).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 34)

                        // Distance
                        VStack(spacing: 2) {
                            Text("Dist")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                            Text("4.8 km")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .minimumScaleFactor(0.7).monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 12)

                Spacer()
            }
        }
    }
}

// MARK: - Screenshot 4: Workout Editor — Yasso 800s

private struct WorkoutEditorScreenshot: View {

    private struct MockStep: Identifiable {
        let id = UUID()
        let indent: Bool
        let symbol: String
        let color: Color
        let label: String
        let detail: String
    }

    private let steps: [MockStep] = [
        .init(indent: false, symbol: "figure.walk",  color: .green,                                      label: "Warmup",       detail: "10 min  ·  E pace  ·  6:00–6:30 /km"),
        .init(indent: false, symbol: "arrow.triangle.2.circlepath", color: accent,                       label: "Repeat × 10",  detail: ""),
        .init(indent: true,  symbol: "flame",         color: Color(red: 0.96,green: 0.26,blue: 0.21),   label: "Run",          detail: "800 m  ·  I pace  ·  4:45–5:05 /km"),
        .init(indent: true,  symbol: "figure.run",   color: .green,                                      label: "Recovery Jog", detail: "400 m  ·  E pace  ·  6:00–6:30 /km"),
        .init(indent: false, symbol: "figure.walk",  color: .green,                                      label: "Cooldown",     detail: "10 min  ·  E pace  ·  6:00–6:30 /km"),
    ]

    var body: some View {
        ZStack {
            black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Nav bar
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold()).foregroundStyle(accent)
                    Spacer()
                    VStack(spacing: 1) {
                        Text("Yasso 800s")
                            .font(.headline).foregroundStyle(textPri)
                        Text("Interval · 10 reps")
                            .font(.caption).foregroundStyle(textSec)
                    }
                    Spacer()
                    Image(systemName: "ellipsis.circle")
                        .font(.title3).foregroundStyle(accent)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)

                // Total stats row
                HStack(spacing: 0) {
                    ForEach([("~16 km","Distance"),("~80 min","Duration"),("I","Zone")], id: \.0) { val, lbl in
                        VStack(spacing: 2) {
                            Text(val)
                                .font(.headline.monospacedDigit()).foregroundStyle(textPri)
                            Text(lbl)
                                .font(.caption2).foregroundStyle(textSec)
                        }
                        .frame(maxWidth: .infinity)
                        if lbl != "Zone" {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 28)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(surface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).padding(.bottom, 20)

                // Steps
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(steps) { step in
                            HStack(spacing: 12) {
                                if step.indent {
                                    Rectangle().fill(Color.clear).frame(width: 20)
                                    Rectangle().fill(accent.opacity(0.4)).frame(width: 2)
                                }
                                Image(systemName: step.symbol)
                                    .font(.title3)
                                    .foregroundStyle(step.color)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(step.label)
                                        .font(step.indent ? .subheadline.bold() : .headline)
                                        .foregroundStyle(textPri)
                                    if !step.detail.isEmpty {
                                        Text(step.detail)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(textSec)
                                    }
                                }
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .font(.subheadline).foregroundStyle(textSec.opacity(0.5))
                            }
                            .padding(.horizontal, step.indent ? 0 : 16)
                            .padding(.vertical, 12)
                            .background(step.indent ? Color.clear : surface, in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, step.indent ? 0 : 16)
                        }
                    }
                    .padding(.bottom, 24)
                }

                // Bottom send button
                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "applewatch")
                        Text("Send to Watch")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Screenshot 5: Widget on Home Screen

private struct WidgetScreenshot: View {
    var body: some View {
        ZStack {
            // Simulated home screen bg
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.10, blue: 0.25), Color(red: 0.08, green: 0.05, blue: 0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // 2×2 small widget row (blurred filler)
                HStack(spacing: 16) {
                    fakeSmallWidget
                    fakeSmallWidget
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 16)

                // Medium RunCraft widget
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0.96, green: 0.26, blue: 0.21))
                            Text("Interval Run")
                                .font(.headline).foregroundStyle(.white)
                        }
                        Text("10 km")
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("I · 4:45–5:05 /km")
                            .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Button { } label: {
                        Label("Start", systemImage: "play.circle.fill")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 28)

                Spacer().frame(height: 16)

                // Dock (blurred filler)
                HStack(spacing: 28) {
                    ForEach(0..<4, id: \.self) { _ in fakeIcon }
                }
                .padding(.horizontal, 32).padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 28)

                Spacer()
            }
        }
    }

    private var fakeSmallWidget: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .frame(width: 155, height: 155)
    }

    private var fakeIcon: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .frame(width: 56, height: 56)
    }
}

// MARK: - Previews

// MARK: - ScreenshotHost (launched via --screenshots argument)

struct ScreenshotHost: View {
    @State private var index: Int = 0

    private let screens: [(String, AnyView)] = [
        ("01-plan",          AnyView(PlanScreenshot())),
        ("02-insights",      AnyView(InsightsScreenshot())),
        ("03-live-activity", AnyView(LiveActivityScreenshot())),
        ("04-editor",        AnyView(WorkoutEditorScreenshot())),
        ("05-widget",        AnyView(WidgetScreenshot())),
    ]

    var body: some View {
        ZStack {
            screens[index].1
                .id(index)
                .preferredColorScheme(.dark)
            // Invisible overlay: tap anywhere to advance (for manual flow)
            Color.clear.contentShape(Rectangle())
                .onTapGesture { index = (index + 1) % screens.count }
        }
        .ignoresSafeArea()
        .onOpenURL { url in
            if let i = Int(url.host ?? "") { index = i }
        }
    }
}

// MARK: - Previews

#Preview("1 — Plan (Week 9, Today=Interval)") {
    PlanScreenshot().preferredColorScheme(.dark)
}

#Preview("2 — Insights (VDOT + Race Preds + LT)") {
    InsightsScreenshot().preferredColorScheme(.dark)
}

#Preview("3 — Live Activity (Lock Screen)") {
    LiveActivityScreenshot().preferredColorScheme(.dark)
}

#Preview("4 — Workout Editor (Yasso 800s)") {
    WorkoutEditorScreenshot().preferredColorScheme(.dark)
}

#Preview("5 — Widget on Home Screen") {
    WidgetScreenshot().preferredColorScheme(.dark)
}
