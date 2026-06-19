import RunCraftModels
import SwiftUI

// MARK: - ActiveWorkoutView

struct ActiveWorkoutView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @State private var showEndConfirmation = false

    var body: some View {
        TabView {
            MetricsTabView(manager: manager)
            controlsPage
        }
        .tabViewStyle(.page)
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) { manager.endWorkout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var controlsPage: some View {
        VStack(spacing: 14) {
            if case .paused = manager.phase {
                Button("Resume") { manager.resumeWorkout() }
                    .tint(.green)
            } else {
                Button("Pause") { manager.pauseWorkout() }
                    .tint(.yellow)
            }
            Button("End Workout") { showEndConfirmation = true }
                .tint(.red)
        }
        .padding()
    }
}

// MARK: - Metrics tab (vertical-paging between 3 views)

private struct MetricsTabView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @State private var page: Int? = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    IntervalPageView(manager: manager)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(0)
                    HRZonePageView(manager: manager)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(1)
                    PacePageView(manager: manager)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(2)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .clipped()

            PageDotsIndicator(currentPage: page ?? 0, pageCount: 3)
                .padding(.trailing, 2)
        }
    }
}

// MARK: - Page dots (right-side vertical indicator)

private struct PageDotsIndicator: View {
    let currentPage: Int
    let pageCount: Int

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<pageCount, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: i == currentPage ? 5 : 4, height: i == currentPage ? 5 : 4)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Page 0: Interval view

private struct IntervalPageView: View {
    @ObservedObject var manager: WorkoutSessionManager

    private var stepColor: Color { manager.stepKind.watchColor }
    private var hrZoneColor: Color { manager.hrZoneNumber.hrZoneColor }

    var body: some View {
        VStack(spacing: 0) {
            // Step badge: icon + name + position
            HStack(spacing: 4) {
                if let kind = manager.stepKind {
                    Image(systemName: kind.symbolName)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(manager.stepName.isEmpty ? "Workout" : manager.stepName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if manager.totalStepCount > 1 {
                    Text("\(manager.stepPosition)/\(manager.totalStepCount)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(stepColor)
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Spacer()

            // Hero: elapsed time
            Text(manager.elapsedTimeText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(stepColor)

            Spacer()

            // Three metrics: Pace | HR+zone | Remaining
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(manager.paceText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(manager.paceUnitLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .center, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(hrZoneColor)
                            .monospacedDigit()
                        Text("bpm")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    // Zone dots
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { z in
                            Circle()
                                .fill(z <= manager.hrZoneNumber ? hrZoneColor : Color.secondary.opacity(0.25))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(manager.stepRemainingText.isEmpty ? "--" : manager.stepRemainingText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                    Text("left")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)

            Spacer()

            // Step progress bar + goal
            VStack(alignment: .leading, spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule()
                            .fill(stepColor)
                            .frame(width: geo.size.width * CGFloat(manager.stepProgress))
                            .animation(.linear(duration: 0.35), value: manager.stepProgress)
                    }
                }
                .frame(height: 5)
                if !manager.stepGoalText.isEmpty {
                    Text("Goal: \(manager.stepGoalText)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            // Next step hint
            if !manager.nextStepSummary.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                    Text(manager.nextStepSummary)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 3)
            }

            Spacer(minLength: 4)
        }
    }
}

// MARK: - Page 1: HR Zone view

private struct HRZonePageView: View {
    @ObservedObject var manager: WorkoutSessionManager

    private var hrZoneColor: Color { manager.hrZoneNumber.hrZoneColor }

    var body: some View {
        VStack(spacing: 0) {
            // Small elapsed time at top
            Text(manager.elapsedTimeText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            Spacer()

            // Large HR
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(hrZoneColor)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 1) {
                    Text("bpm")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(hrZoneColor)
                }
            }

            // Zone badge
            if manager.hrZoneNumber > 0 {
                Text("Zone \(manager.hrZoneNumber)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(hrZoneColor, in: Capsule())
                    .padding(.top, 4)
            }

            Spacer()

            // Five-zone bar
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { z in
                    Capsule()
                        .fill(z <= manager.hrZoneNumber ? z.hrZoneColor : Color.secondary.opacity(0.2))
                        .frame(height: 5)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Secondary metrics: avg pace | avg HR
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(manager.avgPaceText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("avg \(manager.paceUnitLabel)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 24)

                VStack(spacing: 2) {
                    Text(manager.avgHeartRate > 0 ? "\(Int(manager.avgHeartRate))" : "--")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(hrZoneColor)
                    Text("avg bpm")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 4)
        }
    }
}

// MARK: - Page 2: Pace & Distance view

private struct PacePageView: View {
    @ObservedObject var manager: WorkoutSessionManager

    private var paceDeviationColor: Color {
        guard let lo = manager.targetPaceLo, let hi = manager.targetPaceHi,
              manager.paceSecPerKm > 0 else { return .white }
        if manager.paceSecPerKm < Double(lo) { return .cyan }
        if manager.paceSecPerKm > Double(hi) { return .orange }
        return .green
    }

    private var paceDeviationLabel: String? {
        guard let lo = manager.targetPaceLo, let hi = manager.targetPaceHi,
              manager.paceSecPerKm > 0 else { return nil }
        if manager.paceSecPerKm < Double(lo) { return "↑ Ahead" }
        if manager.paceSecPerKm > Double(hi) { return "↓ Behind" }
        return "On Target"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Small elapsed time
            Text(manager.elapsedTimeText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            Spacer()

            // Current pace (large) + deviation badge
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(manager.paceText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(paceDeviationColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.paceUnitLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if let label = paceDeviationLabel {
                        Text(label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(paceDeviationColor)
                    }
                }
            }

            // Target pace range indicator
            if let lo = manager.targetPaceLo, let hi = manager.targetPaceHi {
                PaceRangeBar(
                    current: manager.paceSecPerKm,
                    lo: lo, hi: hi
                )
                .padding(.horizontal, 8)
                .padding(.top, 4)

                HStack {
                    Text(manager.targetPaceText(lo))
                    Spacer()
                    Text("Target")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(manager.targetPaceText(hi))
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 1)
            }

            Spacer()

            // Distance + avg pace
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(manager.distanceText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("dist")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 24)

                VStack(spacing: 2) {
                    Text(manager.avgPaceText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("avg \(manager.paceUnitLabel)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 4)
        }
    }
}

// MARK: - Pace range bar

private struct PaceRangeBar: View {
    let current: Double
    let lo: Int
    let hi: Int

    private var deviationColor: Color {
        if current < Double(lo) { return .cyan }
        if current > Double(hi) { return .orange }
        return .green
    }

    var body: some View {
        GeometryReader { geo in
            let margin = max(Double(hi - lo) * 0.6, 20.0)
            let totalRange = Double(hi - lo) + 2 * margin
            let w = Double(geo.size.width)

            let loX  = CGFloat(margin / totalRange * w)
            let hiX  = CGFloat((Double(hi - lo) + margin) / totalRange * w)
            let curX = CGFloat(max(0, min(w, (current - Double(lo) + margin) / totalRange * w)))

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 6)

                // Target zone highlight
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green.opacity(0.35))
                    .frame(width: max(0, hiX - loX), height: 6)
                    .offset(x: loX)

                // Current pace dot
                Circle()
                    .fill(deviationColor)
                    .frame(width: 10, height: 10)
                    .offset(x: curX - 5, y: -2)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Color helpers

private extension Optional where Wrapped == StepKind {
    var watchColor: Color {
        switch self {
        case .warmup:   .orange
        case .work:     .green
        case .recovery: .cyan
        case .cooldown: .yellow
        case nil:       .blue
        }
    }
}

private extension Int {
    var hrZoneColor: Color {
        switch self {
        case 1:  .blue
        case 2:  .green
        case 3:  .yellow
        case 4:  .orange
        case 5:  .red
        default: .secondary
        }
    }
}

// MARK: - Previews

#Preview("Interval — work step") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.stepName = "Rep 2/5 · Run"
        m.stepGoalText = "1000 m"
        m.stepProgress = 0.68
        m.stepKind = .work
        m.heartRate = 162
        m.avgHeartRate = 158
        m.paceSecPerKm = 302    // 5'02"
        m.avgPaceSecPerKm = 310 // 5'10"
        m.targetPaceLo = 285    // 4'45"
        m.targetPaceHi = 315    // 5'15"
        m.totalMetres = 1680
        m.elapsedSeconds = 487
        m.stepPosition = 4
        m.totalStepCount = 12
        m.nextStepSummary = "Rep 2/5 · Recovery · 90 sec"
        m.stepRemainingText = "320 m"
        return m
    }())
}

#Preview("Interval — warmup") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.stepName = "Warm-up"
        m.stepGoalText = "5 min"
        m.stepProgress = 0.3
        m.stepKind = .warmup
        m.heartRate = 128
        m.avgHeartRate = 122
        m.paceSecPerKm = 360
        m.avgPaceSecPerKm = 370
        m.totalMetres = 420
        m.elapsedSeconds = 90
        m.stepPosition = 1
        m.totalStepCount = 12
        m.nextStepSummary = "Rep 1/5 · Run · 1 km"
        m.stepRemainingText = "3:30"
        return m
    }())
}

#Preview("HR Zone view") {
    HRZonePageView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.heartRate = 171
        m.avgHeartRate = 163
        m.paceSecPerKm = 295
        m.avgPaceSecPerKm = 308
        m.elapsedSeconds = 1372
        return m
    }())
}

#Preview("Pace view — on target") {
    PacePageView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.paceSecPerKm = 302    // 5'02" — within 4'45"–5'15"
        m.avgPaceSecPerKm = 308 // 5'08"
        m.targetPaceLo = 285    // 4'45"
        m.targetPaceHi = 315    // 5'15"
        m.totalMetres = 3620
        m.elapsedSeconds = 1372
        return m
    }())
    .padding(.horizontal, 4)
}

#Preview("Pace view — behind") {
    PacePageView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.paceSecPerKm = 340    // 5'40" — too slow
        m.avgPaceSecPerKm = 325
        m.targetPaceLo = 285
        m.targetPaceHi = 315
        m.totalMetres = 2340
        m.elapsedSeconds = 892
        return m
    }())
    .padding(.horizontal, 4)
}

#Preview("Pace view — ahead") {
    PacePageView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.paceSecPerKm = 268    // 4'28" — too fast
        m.avgPaceSecPerKm = 278
        m.targetPaceLo = 285
        m.targetPaceHi = 315
        m.totalMetres = 4100
        m.elapsedSeconds = 1372
        return m
    }())
    .padding(.horizontal, 4)
}

#Preview("Pace view — no target") {
    PacePageView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .running
        m.paceSecPerKm = 350
        m.avgPaceSecPerKm = 365
        m.totalMetres = 5200
        m.elapsedSeconds = 1920
        return m
    }())
    .padding(.horizontal, 4)
}

#Preview("Controls") {
    ActiveWorkoutView(manager: {
        let m = WorkoutSessionManager()
        m.phase = .paused
        return m
    }())
}
