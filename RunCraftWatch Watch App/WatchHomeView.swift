import AppleWatchSync
import RunCraftModels
import SwiftUI

// MARK: - WatchHomeView

struct WatchHomeView: View {
    let schedule: WatchSchedulePayload?
    @ObservedObject var manager: WorkoutSessionManager

    var body: some View {
        if let schedule, !schedule.sessions.isEmpty || !schedule.paceTemplates.isEmpty {
            NavigationStack {
                TabView {
                    if !schedule.sessions.isEmpty {
                        SessionsWheelView(sessions: schedule.sessions, manager: manager)
                    }
                    if !schedule.paceTemplates.isEmpty {
                        PacesWheelView(templates: schedule.paceTemplates, manager: manager)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: schedule.paceTemplates.isEmpty ? .never : .automatic))
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Open RunCraft on your iPhone to sync your schedule.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - Sessions vertical wheel

private struct SessionsWheelView: View {
    let sessions: [WatchSchedulePayload.Session]
    @ObservedObject var manager: WorkoutSessionManager
    @State private var scrollID: UUID?

    /// Today-first order, then upcoming by day-of-week, then past sessions last.
    private var sorted: [WatchSchedulePayload.Session] {
        let todayDOW = PlannedSession.dayOfWeek(for: Date())
        return sessions.sorted { lhs, rhs in
            let lOffset = (lhs.dayOfWeek - todayDOW + 7) % 7
            let rOffset = (rhs.dayOfWeek - todayDOW + 7) % 7
            return lOffset < rOffset
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cardH = geo.size.height * 0.80
            let vInset = (geo.size.height - cardH) / 2

            ScrollView(.vertical) {
                LazyVStack(spacing: 8) {
                    ForEach(sorted) { session in
                        NavigationLink {
                            WorkoutStartView(
                                name: session.title,
                                payload: session.payload,
                                manager: manager
                            )
                        } label: {
                            SessionWheelCard(session: session)
                        }
                        .buttonStyle(.plain)
                        .frame(width: geo.size.width - 4, height: cardH)
                        .id(session.id)
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.82)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, vInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollID)
            .scrollIndicators(.hidden)
        }
        .task {
            guard scrollID == nil else { return }
            scrollID = sorted.first?.id
        }
    }
}

// MARK: - Training Paces vertical wheel

private struct PacesWheelView: View {
    let templates: [WatchWorkoutPayload]
    @ObservedObject var manager: WorkoutSessionManager

    var body: some View {
        GeometryReader { geo in
            let cardH = geo.size.height * 0.80
            let vInset = (geo.size.height - cardH) / 2

            ScrollView(.vertical) {
                LazyVStack(spacing: 8) {
                    ForEach(templates, id: \.name) { template in
                        NavigationLink {
                            WorkoutStartView(
                                name: template.name,
                                payload: template,
                                manager: manager
                            )
                        } label: {
                            PaceWheelCard(template: template)
                        }
                        .buttonStyle(.plain)
                        .frame(width: geo.size.width - 4, height: cardH)
                        .id(template.name)
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.82)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, vInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Session card

private struct SessionWheelCard: View {
    let session: WatchSchedulePayload.Session

    private var bgColor: Color {
        session.isPast ? Color(white: 0.18) : session.sessionType.watchColor
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(bgColor)

            // No Spacer() — ZStack centres the block automatically.
            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: session.sessionType.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Day / Today
                Group {
                    if session.isToday {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.2), in: Capsule())
                    } else {
                        Text(session.dayName.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 5)

                // Title
                Text(session.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 12)
                    .padding(.top, 3)

                // Separator
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                // Goal metric — value + unit only (no redundant label)
                if let metric = sessionGoalMetric(session.payload) {
                    Text(metric.value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(metric.unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 1)
                }

                // Step dots
                let steps = totalSteps(session.payload)
                if steps > 1 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(steps, 7), id: \.self) { _ in
                            Capsule()
                                .fill(.white.opacity(0.35))
                                .frame(width: 9, height: 2.5)
                        }
                        if steps > 7 {
                            Text("+\(steps - 7)")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(session.isToday ? 0.5 : 0), lineWidth: 1.5)
        )
    }
}

// MARK: - Pace card

private struct PaceWheelCard: View {
    let template: WatchWorkoutPayload

    private var bgColor: Color { zoneCardColor(template.zoneLetter) }
    private var letter: String { template.zoneLetter ?? "?" }
    private var fullName: String {
        switch template.zoneLetter {
        case "E": "EASY"
        case "M": "MARATHON"
        case "T": "THRESHOLD"
        case "I": "INTERVAL"
        case "R": "REPETITION"
        default:  "PACE"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(bgColor)

            VStack(spacing: 0) {
                // Zone letter in circle
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Text(letter)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text(fullName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 5)

                Text(template.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 12)
                    .padding(.top, 3)

                // Separator
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                // Pace range
                let paceStr = primaryPaceText(template) ?? template.subtitle
                if let paceStr {
                    Text(paceStr)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - SessionType helpers

extension SessionType {
    var watchColor: Color {
        switch self {
        case .easy:       .green
        case .tempo:      Color(hue: 0.13, saturation: 0.85, brightness: 0.9) // amber — white text readable
        case .interval:   .red
        case .long:       .blue
        case .repetition: .orange
        case .rest:       Color(white: 0.28)
        case .fartlek:    .purple
        case .mixed:      .cyan
        }
    }
}

// MARK: - Private helpers

private struct GoalMetric {
    var label: String   // "DISTANCE" / "TIME"
    var value: String   // e.g. "8", "30"
    var unit: String    // "km" / "min" / "h"
}

private func sessionGoalMetric(_ payload: WatchWorkoutPayload) -> GoalMetric? {
    let totalM = totalDistanceMeters(payload)
    if totalM >= 500 {
        if totalM >= 1000 {
            let km = totalM / 1000
            let valStr = km == km.rounded(.towardZero)
                ? "\(Int(km))"
                : String(format: "%.1f", km)
            return GoalMetric(label: "DISTANCE", value: valStr, unit: "km")
        }
        return GoalMetric(label: "DISTANCE", value: "\(Int(totalM))", unit: "m")
    }
    let totalSec = totalTimeSeconds(payload)
    if totalSec > 0 {
        let mins = totalSec / 60
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return GoalMetric(
                label: "TIME",
                value: m > 0 ? "\(h):\(String(format: "%02d", m))" : "\(h)",
                unit: m > 0 ? "h" : "hr"
            )
        }
        return GoalMetric(label: "TIME", value: "\(mins)", unit: "min")
    }
    return nil
}

private func zoneCardColor(_ letter: String?) -> Color {
    switch letter {
    case "E": .green
    case "M": .blue
    case "T": Color(hue: 0.13, saturation: 0.85, brightness: 0.9) // amber
    case "I": .orange
    case "R": .red
    default:  .gray
    }
}

private func allSteps(_ payload: WatchWorkoutPayload) -> [WorkoutStep] {
    payload.blocks.flatMap { block -> [WorkoutStep] in
        switch block {
        case .step(let s): [s]
        case .repeatGroup(let g): Array(repeating: g.steps, count: g.iterations).flatMap { $0 }
        }
    }
}

private func totalSteps(_ payload: WatchWorkoutPayload) -> Int { allSteps(payload).count }

private func totalDistanceMeters(_ payload: WatchWorkoutPayload) -> Double {
    allSteps(payload).reduce(0) { acc, step in
        if case .distance(let m) = step.goal { return acc + m }
        return acc
    }
}

private func totalTimeSeconds(_ payload: WatchWorkoutPayload) -> Int {
    allSteps(payload).reduce(0) { acc, step in
        if case .time(let s) = step.goal { return acc + s }
        return acc
    }
}

private func primaryPaceText(_ payload: WatchWorkoutPayload) -> String? {
    for block in payload.blocks {
        let steps: [WorkoutStep]
        switch block {
        case .step(let s): steps = [s]
        case .repeatGroup(let g): steps = g.steps
        }
        for s in steps {
            if let alert = s.alert, case .paceRange(let lo, let hi) = alert {
                return "\(formatPaceSec(lo))–\(formatPaceSec(hi)) /km"
            }
        }
    }
    return nil
}

private func formatPaceSec(_ sec: Int) -> String {
    String(format: "%d:%02d", sec / 60, sec % 60)
}

// MARK: - Previews

#Preview("Has today + upcoming + paces") {
    let easyPayload = WatchWorkoutPayload(name: "Easy Run", blocks: [
        .step(WorkoutStep(kind: .warmup,   goal: .time(seconds: 5 * 60))),
        .step(WorkoutStep(kind: .work,     goal: .distance(metres: 8_000))),
        .step(WorkoutStep(kind: .cooldown, goal: .time(seconds: 5 * 60))),
    ])
    let intervalPayload = WatchWorkoutPayload(name: "Intervals", blocks: [
        .step(WorkoutStep(kind: .warmup, goal: .time(seconds: 10 * 60))),
        .repeatGroup(RepeatGroup(iterations: 5, steps: [
            WorkoutStep(kind: .work,     goal: .distance(metres: 1_000)),
            WorkoutStep(kind: .recovery, goal: .time(seconds: 90)),
        ])),
        .step(WorkoutStep(kind: .cooldown, goal: .time(seconds: 5 * 60))),
    ])
    let longPayload = WatchWorkoutPayload(name: "Long Run", blocks: [
        .step(WorkoutStep(kind: .warmup, goal: .time(seconds: 10 * 60))),
        .step(WorkoutStep(kind: .work,   goal: .distance(metres: 24_000))),
        .step(WorkoutStep(kind: .cooldown, goal: .time(seconds: 5 * 60))),
    ])
    let easyPace = WatchWorkoutPayload(name: "Easy Run · 30 min", zoneLetter: "E", blocks: [
        .step(WorkoutStep(kind: .work, goal: .time(seconds: 30 * 60),
                          alert: .paceRange(minSecPerKm: 360, maxSecPerKm: 420))),
    ])
    let tempoPace = WatchWorkoutPayload(name: "Threshold · 20 min", zoneLetter: "T", blocks: [
        .step(WorkoutStep(kind: .work, goal: .time(seconds: 20 * 60),
                          alert: .paceRange(minSecPerKm: 255, maxSecPerKm: 270))),
    ])

    // Thursday = dayOfWeek 4 (Mon=1), today is Thursday 2026-06-19
    let schedule = WatchSchedulePayload(
        sessions: [
            .init(id: UUID(), dayName: "Mon", title: "Easy Run",  sessionType: .easy,     dayOfWeek: 1, payload: easyPayload),
            .init(id: UUID(), dayName: "Wed", title: "Intervals", sessionType: .interval, dayOfWeek: 3, payload: intervalPayload),
            .init(id: UUID(), dayName: "Thu", title: "Long Run",  sessionType: .long,     dayOfWeek: 4, payload: longPayload),
            .init(id: UUID(), dayName: "Sat", title: "Easy Run",  sessionType: .easy,     dayOfWeek: 6, payload: easyPayload),
        ],
        paceTemplates: [easyPace, tempoPace]
    )
    WatchHomeView(schedule: schedule, manager: WorkoutSessionManager())
}

#Preview("Sessions only — no paces") {
    let tempoPayload = WatchWorkoutPayload(name: "Tempo Run", blocks: [
        .step(WorkoutStep(kind: .warmup, goal: .time(seconds: 10 * 60))),
        .step(WorkoutStep(kind: .work,   goal: .distance(metres: 10_000))),
        .step(WorkoutStep(kind: .cooldown, goal: .time(seconds: 5 * 60))),
    ])
    let schedule = WatchSchedulePayload(
        sessions: [
            .init(id: UUID(), dayName: "Tue", title: "Tempo Run", sessionType: .tempo, dayOfWeek: 2, payload: tempoPayload),
            .init(id: UUID(), dayName: "Thu", title: "Easy Run",  sessionType: .easy,  dayOfWeek: 4, payload: tempoPayload),
        ],
        paceTemplates: []
    )
    WatchHomeView(schedule: schedule, manager: WorkoutSessionManager())
}

#Preview("No schedule — sync prompt") {
    WatchHomeView(schedule: nil, manager: WorkoutSessionManager())
}
