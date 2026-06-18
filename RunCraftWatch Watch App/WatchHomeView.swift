import AppleWatchSync
import RunCraftModels
import SwiftUI

struct WatchHomeView: View {
    let schedule: WatchSchedulePayload?
    @ObservedObject var manager: WorkoutSessionManager

    var body: some View {
        NavigationStack {
            if let schedule, !schedule.sessions.isEmpty || !schedule.paceTemplates.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        if !schedule.sessions.isEmpty {
                            sessionsSection(schedule.sessions)
                        }
                        if !schedule.paceTemplates.isEmpty {
                            paceTemplatesSection(schedule.paceTemplates)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
                .navigationTitle("RunCraft")
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
                .navigationTitle("RunCraft")
            }
        }
    }

    // MARK: - Sessions

    @ViewBuilder
    private func sessionsSection(_ sessions: [WatchSchedulePayload.Session]) -> some View {
        let sorted = sessions.sorted { lhs, rhs in
            if lhs.isToday != rhs.isToday { return lhs.isToday }
            return lhs.isPast == rhs.isPast ? false : !lhs.isPast
        }

        if let today = sorted.first(where: \.isToday) {
            NavigationLink {
                WorkoutStartView(name: today.title, payload: today.payload, manager: manager)
            } label: {
                TodayCard(session: today)
            }
            .buttonStyle(.plain)
        }

        let rest = sorted.filter { !$0.isToday }
        if !rest.isEmpty {
            VStack(spacing: 4) {
                ForEach(rest) { session in
                    NavigationLink {
                        WorkoutStartView(name: session.title, payload: session.payload, manager: manager)
                    } label: {
                        CompactSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Pace templates

    @ViewBuilder
    private func paceTemplatesSection(_ templates: [WatchWorkoutPayload]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Training Paces")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ForEach(templates, id: \.name) { template in
                let zColor = zoneColor(template.zoneLetter)
                let zSymbol = zoneSymbol(template.zoneLetter)
                NavigationLink {
                    WorkoutStartView(name: template.name, payload: template, manager: manager)
                } label: {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(zColor.opacity(0.12))

                        // Left accent bar flush to edge
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(zColor)
                                .frame(width: 3)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        HStack(spacing: 8) {
                            Image(systemName: zSymbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(zColor)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(template.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                let pace = primaryPaceText(template) ?? template.subtitle
                                if let pace {
                                    Text(pace)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 10)
                        .padding(.vertical, 8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func zoneColor(_ letter: String?) -> Color {
        switch letter {
        case "E": .green
        case "M": .blue
        case "T": .yellow
        case "I": .orange
        case "R": .red
        default:  .secondary
        }
    }

    private func zoneSymbol(_ letter: String?) -> String {
        switch letter {
        case "E": "figure.run"
        case "M": "figure.run.circle"
        case "T": "flame"
        case "I": "bolt"
        case "R": "bolt.circle"
        default:  "figure.run"
        }
    }
}

// MARK: - TodayCard

private struct TodayCard: View {
    let session: WatchSchedulePayload.Session

    private var sessionColor: Color { session.sessionType.watchColor }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(sessionColor.opacity(0.18))

            // Left accent bar
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(sessionColor)
                    .frame(width: 3)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                // Header row: icon + "Today" badge
                HStack(spacing: 6) {
                    Image(systemName: session.sessionType.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(sessionColor)
                    Spacer()
                    Text("Today")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(sessionColor, in: Capsule())
                }

                // Session title
                Text(session.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                // Goal summary: distance/time + pace range
                let summary = sessionSummary(session.payload)
                let pace = primaryPaceText(session.payload)
                if !summary.isEmpty || pace != nil {
                    HStack(spacing: 4) {
                        if !summary.isEmpty {
                            Text(summary)
                        }
                        if !summary.isEmpty, pace != nil {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        if let pace {
                            Text(pace)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }

                // Step count hint
                let stepCount = totalSteps(session.payload)
                if stepCount > 1 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(stepCount, 7), id: \.self) { _ in
                            Capsule()
                                .fill(sessionColor.opacity(0.6))
                                .frame(width: 10, height: 3)
                        }
                        if stepCount > 7 {
                            Text("+\(stepCount - 7)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 10)
        }
        .frame(minHeight: 90)
    }
}

// MARK: - CompactSessionRow

private struct CompactSessionRow: View {
    let session: WatchSchedulePayload.Session

    private var sessionColor: Color {
        session.isPast ? .secondary : session.sessionType.watchColor
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sessionColor.opacity(session.isPast ? 0.4 : 1))
                .frame(width: 8, height: 8)

            Text(session.dayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)

            Image(systemName: session.sessionType.symbolName)
                .font(.system(size: 11))
                .foregroundStyle(sessionColor)

            Text(session.title)
                .font(.system(size: 13))
                .foregroundStyle(session.isPast ? .secondary : .primary)

            Spacer(minLength: 0)

            let dist = compactDistanceText(session.payload)
            if !dist.isEmpty {
                Text(dist)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .opacity(session.isPast ? 0.6 : 1)
    }
}

// MARK: - Helpers

private func sessionSummary(_ payload: WatchWorkoutPayload) -> String {
    let totalM = totalDistanceMeters(payload)
    if totalM >= 500 {
        if totalM >= 1000 {
            return String(format: "%.0f km", totalM / 1_000)
        }
        return "\(Int(totalM)) m"
    }
    let totalSec = totalTimeSeconds(payload)
    if totalSec > 0 {
        let mins = totalSec / 60
        return "\(mins) min"
    }
    return ""
}

private func compactDistanceText(_ payload: WatchWorkoutPayload) -> String {
    let totalM = totalDistanceMeters(payload)
    guard totalM >= 500 else { return "" }
    if totalM >= 1000 { return String(format: "%.0f km", totalM / 1_000) }
    return "\(Int(totalM)) m"
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

/// Returns the pace-range string from the first step that carries a paceRange alert.
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

// MARK: - SessionType + watchColor

extension SessionType {
    var watchColor: Color {
        switch self {
        case .easy:       .green
        case .tempo:      .yellow
        case .interval:   .red
        case .long:       .blue
        case .repetition: .orange
        case .rest:       .secondary
        case .fartlek:    .purple
        case .mixed:      Color(white: 0.5)
        }
    }
}

// MARK: - Previews

#Preview("Has today + upcoming") {
    let easyPayload = WatchWorkoutPayload(name: "Easy Run", blocks: [
        .step(WorkoutStep(kind: .warmup, goal: .time(seconds: 5 * 60))),
        .step(WorkoutStep(kind: .work,   goal: .distance(metres: 8_000))),
        .step(WorkoutStep(kind: .cooldown, goal: .time(seconds: 5 * 60))),
    ])
    let longPayload = WatchWorkoutPayload(name: "Long Run", blocks: [
        .step(WorkoutStep(kind: .warmup, goal: .time(seconds: 10 * 60))),
        .step(WorkoutStep(kind: .work,   goal: .distance(metres: 24_000))),
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

    let schedule = WatchSchedulePayload(
        sessions: [
            .init(id: UUID(), dayName: "Mon", title: "Easy Run",    sessionType: .easy,     isToday: false, isPast: true,  payload: easyPayload),
            .init(id: UUID(), dayName: "Wed", title: "Intervals",   sessionType: .interval, isToday: false, isPast: true,  payload: intervalPayload),
            .init(id: UUID(), dayName: "Fri", title: "Long Run",    sessionType: .long,     isToday: true,  isPast: false, payload: longPayload),
            .init(id: UUID(), dayName: "Sat", title: "Easy Run",    sessionType: .easy,     isToday: false, isPast: false, payload: easyPayload),
        ],
        paceTemplates: []
    )
    WatchHomeView(schedule: schedule, manager: WorkoutSessionManager())
}

#Preview("No today session") {
    let tempoPayload = WatchWorkoutPayload(name: "Tempo Run", blocks: [
        .step(WorkoutStep(kind: .warmup, goal: .time(seconds: 10 * 60))),
        .step(WorkoutStep(kind: .work,   goal: .distance(metres: 10_000))),
        .step(WorkoutStep(kind: .cooldown, goal: .time(seconds: 5 * 60))),
    ])
    let schedule = WatchSchedulePayload(
        sessions: [
            .init(id: UUID(), dayName: "Tue", title: "Tempo Run", sessionType: .tempo,  isToday: false, isPast: false, payload: tempoPayload),
            .init(id: UUID(), dayName: "Thu", title: "Easy Run",  sessionType: .easy,   isToday: false, isPast: false, payload: tempoPayload),
        ],
        paceTemplates: []
    )
    WatchHomeView(schedule: schedule, manager: WorkoutSessionManager())
}
