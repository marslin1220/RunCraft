//
//  WorkoutSessionManager.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/16.
//

import AppleWatchSync
import AVFoundation
import Combine
import Foundation
import HealthKit
import os
import RunCraftModels
import WatchKit

private let sessionLogger = Logger(subsystem: "io.marstudio.RunCraft.watchkitapp", category: "WorkoutSession")

@MainActor
final class WorkoutSessionManager: NSObject, ObservableObject {

    struct WorkoutSummaryData: Equatable {
        let totalMetres: Double
        let elapsedSeconds: Int
        let avgPaceSecPerKm: Double
        let avgHeartRate: Double
        let calories: Double
    }

    enum Phase: Equatable {
        case inactive
        case countdown(Int)   // 3 → 2 → 1 before session.startActivity
        case running
        case openGoal         // structured blocks done; keep recording until user stops
        case paused
        case summary(WorkoutSummaryData)
        case failed(String)
    }

    @Published var phase: Phase = .inactive
    @Published var elapsedSeconds: Int = 0
    @Published var heartRate: Double = 0
    @Published var avgHeartRate: Double = 0
    @Published var paceSecPerKm: Double = 0
    @Published var avgPaceSecPerKm: Double = 0
    /// Lower bound of the current step's target pace range (sec/km). `nil` when the step has no pace alert.
    @Published var targetPaceLo: Int? = nil
    /// Upper bound of the current step's target pace range (sec/km). `nil` when the step has no pace alert.
    @Published var targetPaceHi: Int? = nil
    @Published var totalMetres: Double = 0
    @Published var stepName: String = ""
    @Published var stepGoalText: String = ""
    @Published var stepProgress: Double = 0
    @Published var stepKind: StepKind? = nil
    /// "Rep 3/5 · Recovery · 90 sec" — empty string when on the last step.
    @Published var nextStepSummary: String = ""
    /// Countdown/remaining for the current step: "380 m", "1:48". Empty for open-ended steps.
    @Published var stepRemainingText: String = ""
    /// 1-based position for display, e.g. "3 / 12".
    @Published var stepPosition: Int = 0
    @Published var totalStepCount: Int = 0

    /// Current HR zone (1–5). 0 when heart rate is unavailable.
    var hrZoneNumber: Int {
        guard heartRate > 0 else { return 0 }
        if heartRate < 120 { return 1 }
        if heartRate < 140 { return 2 }
        if heartRate < 160 { return 3 }
        if heartRate < 175 { return 4 }
        return 5
    }

    @Published var showStepTransition: Bool = false

    private var previousStepDisplayName: String = ""
    private lazy var speechSynthesizer: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = self
        return s
    }()

    private var isEnding = false
    private var stepTransitionTask: Task<Void, Never>?

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var flatSteps: [(step: WorkoutStep, displayName: String)] = []
    private var currentStepIndex: Int = 0
    private var stepStartMetres: Double = 0
    private var stepStartDate: Date = Date()

    private var openGoalActive: Bool = false

    private var elapsedTimerTask: Task<Void, Never>?
    private var stepTimerTask: Task<Void, Never>?

    /// Runs the 3-2-1 countdown, playing a click haptic on each beat.
    /// Call this before `startWorkout` — it transitions phase through `.countdown(3/2/1)`.
    func runCountdown() async {
        for n in stride(from: 3, through: 1, by: -1) {
            phase = .countdown(n)
            WKInterfaceDevice.current().play(.click)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func startWorkout(session: HKWorkoutSession, blocks: [WorkoutBlock], healthStore: HKHealthStore) async throws {
        self.session = session
        session.delegate = self

        let builder = session.associatedWorkoutBuilder()
        self.builder = builder
        builder.delegate = self
        let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: session.workoutConfiguration)
        // Explicitly enable runningSpeed so the builder starts collecting it
        // immediately rather than waiting for automatic type detection.
        dataSource.enableCollection(for: HKQuantityType(.runningSpeed), predicate: nil)
        builder.dataSource = dataSource

        isEnding = false
        flatSteps = flattenBlocks(blocks)
        currentStepIndex = 0
        totalStepCount = flatSteps.count

        // Follow Apple's sample order: mirror → startActivity → beginCollection.
        // Calling beginCollection before startActivity puts HKLiveWorkoutBuilder
        // into an error state it cannot recover from.
        do {
            try await session.startMirroringToCompanionDevice()
            sessionLogger.log("startMirroringToCompanionDevice succeeded")
        } catch {
            sessionLogger.warning("startMirroringToCompanionDevice failed (non-fatal): \(error.localizedDescription, privacy: .public)")
        }

        let startDate = Date()
        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)

        // Adding a marker event immediately after beginCollection nudges
        // HKLiveWorkoutBuilder into requesting data right away, which reduces
        // the latency before the first HR/pace samples arrive from the sensor.
        let markerEvent = HKWorkoutEvent(type: .marker, dateInterval: DateInterval(start: startDate, duration: 0), metadata: nil)
        builder.addWorkoutEvents([markerEvent]) { _, _ in }

        phase = .running
        startElapsedTimer()
        updateCurrentStep()
    }

    func endWorkout() {
        guard !isEnding,
              phase == .running || phase == .paused || phase == .openGoal
        else { return }
        isEnding = true
        openGoalActive = false
        session?.end()
    }

    func dismissSummary() {
        builder = nil
        session = nil
        isEnding = false
        phase = .inactive
    }

    func pauseWorkout() {
        session?.pause()
    }

    func resumeWorkout() {
        session?.resume()
    }

    // MARK: - Interval state machine

    private func flattenBlocks(_ blocks: [WorkoutBlock]) -> [(step: WorkoutStep, displayName: String)] {
        var result: [(WorkoutStep, String)] = []
        for block in blocks {
            switch block {
            case .step(let s):
                result.append((s, s.kind.localizedName))
            case .repeatGroup(let g):
                let n = g.iterations
                for i in 1...max(1, n) {
                    for s in g.steps {
                        let kindName = s.kind.localizedName
                        let label: String
                        if n > 1 {
                            let template = NSLocalizedString(
                                "rep_step_label", value: "Rep %1$lld/%2$lld · %3$@", comment: ""
                            )
                            label = String(format: template, i, n, kindName)
                        } else {
                            label = kindName
                        }
                        result.append((s, label))
                    }
                }
            }
        }
        return result
    }

    private func updateCurrentStep() {
        stepTimerTask?.cancel()
        stepTimerTask = nil

        guard currentStepIndex < flatSteps.count else {
            stepName = ""
            stepGoalText = ""
            stepProgress = 1
            stepKind = nil
            nextStepSummary = ""
            stepPosition = flatSteps.count
            sendMirrorMessage()
            return
        }

        let (step, displayName) = flatSteps[currentStepIndex]
        stepName = displayName
        stepKind = step.kind
        stepStartMetres = totalMetres
        stepStartDate = Date()
        stepProgress = 0
        stepPosition = currentStepIndex + 1

        if let alert = step.alert, case .paceRange(let lo, let hi) = alert {
            targetPaceLo = lo
            targetPaceHi = hi
        } else {
            targetPaceLo = nil
            targetPaceHi = nil
        }

        switch step.goal {
        case .openEnded:
            stepGoalText = "Open"
            stepRemainingText = ""
        case .distance(let metres):
            stepGoalText = metres >= 1000
                ? String(format: "%.1f km", metres / 1000)
                : "\(Int(metres)) m"
            stepRemainingText = stepGoalText
        case .time(let seconds):
            let m = seconds / 60
            let s = seconds % 60
            stepGoalText = s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
            stepRemainingText = String(format: "%d:%02d", m, s)
            startStepTimer(duration: TimeInterval(seconds))
        }

        // Show full-screen step transition overlay, then voice + haptic.
        triggerStepTransition()
        announceStep(name: displayName, goal: stepGoalText, previous: previousStepDisplayName)

        // Build next-step summary
        let nextIdx = currentStepIndex + 1
        if nextIdx < flatSteps.count {
            let (nextStep, nextName) = flatSteps[nextIdx]
            let goalStr: String
            switch nextStep.goal {
            case .openEnded:            goalStr = ""
            case .distance(let m):      goalStr = m >= 1000 ? String(format: "%.1f km", m / 1000) : "\(Int(m)) m"
            case .time(let s):
                let min = s / 60; let sec = s % 60
                goalStr = sec == 0 ? "\(min) min" : "\(min):\(String(format: "%02d", sec))"
            }
            nextStepSummary = goalStr.isEmpty ? nextName : "\(nextName) · \(goalStr)"
        } else {
            nextStepSummary = ""
        }

        sendMirrorMessage()
    }

    private func sendMirrorMessage() {
        guard let session else { return }
        let message = WorkoutMirrorMessage(
            stepName: stepName,
            stepGoalText: stepGoalText,
            stepProgress: stepProgress,
            heartRate: heartRate,
            avgHeartRate: avgHeartRate,
            paceSecPerKm: paceSecPerKm,
            avgPaceSecPerKm: avgPaceSecPerKm,
            targetPaceLo: targetPaceLo,
            targetPaceHi: targetPaceHi,
            totalMetres: totalMetres,
            elapsedSeconds: elapsedSeconds,
            isPaused: phase == .paused,
            hrZone: hrZoneNumber
        )
        guard let data = try? JSONEncoder().encode(message) else { return }
        Task {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                sessionLogger.debug("sendToRemoteWorkoutSession failed (non-fatal): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func advanceStep() {
        previousStepDisplayName = currentStepIndex < flatSteps.count
            ? flatSteps[currentStepIndex].displayName : ""
        currentStepIndex += 1
        if currentStepIndex >= flatSteps.count {
            announceWorkoutComplete()
            enterOpenGoal()
        } else {
            updateCurrentStep()
        }
    }

    private func enterOpenGoal() {
        stepTimerTask?.cancel()
        stepTimerTask = nil
        stepName = String(localized: "Free Run")
        stepGoalText = ""
        stepProgress = 1
        stepKind = nil
        stepRemainingText = ""
        nextStepSummary = ""
        targetPaceLo = nil
        targetPaceHi = nil
        openGoalActive = true
        phase = .openGoal
        sendMirrorMessage()
    }

    private func announceStep(name: String, goal: String, previous: String) {
        WKInterfaceDevice.current().play(.notification)

        // Duck background audio (e.g. podcasts) while the announcement plays.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)

        let voiceName = name.replacingOccurrences(of: " · ", with: " ")
        let text: String
        if previous.isEmpty {
            let template = NSLocalizedString("announce.first", value: "%1$@. Goal: %2$@.", comment: "")
            text = String(format: template, voiceName, goal)
        } else {
            let voicePrev = previous.replacingOccurrences(of: " · ", with: " ")
            let template = NSLocalizedString("announce.transition", value: "%1$@ complete. %2$@. Goal: %3$@.", comment: "")
            text = String(format: template, voicePrev, voiceName, goal)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }

    private func triggerStepTransition() {
        stepTransitionTask?.cancel()
        showStepTransition = true
        stepTransitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.showStepTransition = false }
        }
    }

    private func announceWorkoutComplete() {
        WKInterfaceDevice.current().play(.success)
        let voicePrev = previousStepDisplayName.replacingOccurrences(of: " · ", with: " ")
        let text: String
        if voicePrev.isEmpty {
            text = String(localized: "Workout complete!")
        } else {
            let template = NSLocalizedString("announce.workout_complete", value: "%@ complete. Workout complete!", comment: "")
            text = String(format: template, voicePrev)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        speechSynthesizer.speak(utterance)
    }

    private func startStepTimer(duration: TimeInterval) {
        let start = stepStartDate
        stepTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { break }
                await MainActor.run {
                    let elapsed = Date().timeIntervalSince(start)
                    self.stepProgress = min(elapsed / duration, 1.0)
                    let remaining = max(0, duration - elapsed)
                    let r = Int(remaining.rounded())
                    self.stepRemainingText = String(format: "%d:%02d", r / 60, r % 60)
                    if elapsed >= duration {
                        self.advanceStep()
                    }
                }
            }
        }
    }

    private func startElapsedTimer() {
        let start = Date()
        elapsedTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }
                await MainActor.run {
                    self.elapsedSeconds = Int(Date().timeIntervalSince(start))
                }
            }
        }
    }

    private func stopAllTimers() {
        elapsedTimerTask?.cancel()
        stepTimerTask?.cancel()
        elapsedTimerTask = nil
        stepTimerTask = nil
    }

    // MARK: - Formatted display helpers

    private var isPerMile: Bool {
        UserDefaults(suiteName: "group.io.marstudio.RunCraft")?.string(forKey: "paceUnit") == "perMile"
    }

    var paceUnitLabel: String { isPerMile ? "/mi" : "/km" }

    var elapsedTimeText: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var paceText: String {
        guard paceSecPerKm > 0 else { return "--:--" }
        let paceSeconds = isPerMile ? paceSecPerKm * 1.60934 : paceSecPerKm
        let m = Int(paceSeconds) / 60
        let s = Int(paceSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    var avgPaceText: String {
        guard avgPaceSecPerKm > 0 else { return "--:--" }
        let paceSeconds = isPerMile ? avgPaceSecPerKm * 1.60934 : avgPaceSecPerKm
        let m = Int(paceSeconds) / 60
        let s = Int(paceSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    func targetPaceText(_ secPerKm: Int) -> String {
        let adjusted = isPerMile ? Double(secPerKm) * 1.60934 : Double(secPerKm)
        return String(format: "%d:%02d", Int(adjusted) / 60, Int(adjusted) % 60)
    }

    var distanceText: String {
        if isPerMile {
            let miles = totalMetres / 1609.34
            if miles >= 0.1 {
                return String(format: "%.2f mi", miles)
            }
            return String(format: "%.0f ft", totalMetres * 3.28084)
        }
        if totalMetres >= 1000 {
            return String(format: "%.2f km", totalMetres / 1000)
        }
        return "\(Int(totalMetres)) m"
    }

    /// Formats a distance value (metres) using the user's unit preference.
    func formatDistance(_ metres: Double) -> String {
        if isPerMile {
            let miles = metres / 1609.34
            return miles >= 0.1
                ? String(format: "%.2f mi", miles)
                : String(format: "%.0f ft", metres * 3.28084)
        }
        return metres >= 1000
            ? String(format: "%.2f km", metres / 1000)
            : "\(Int(metres)) m"
    }

    /// Formats elapsed seconds as h:mm:ss or m:ss.
    func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Formats a pace in sec/km (or sec/mi when preference is perMile).
    func formatAvgPace(_ secPerKm: Double) -> String {
        guard secPerKm > 0 else { return "--:--" }
        let paceSeconds = isPerMile ? secPerKm * 1.60934 : secPerKm
        let m = Int(paceSeconds) / 60
        let s = Int(paceSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                // Don't override countdown (session reports running before startActivity in some states)
                // or open-goal (resume after pause while in open-goal should restore open-goal).
                if case .countdown = self.phase { break }
                self.phase = self.openGoalActive ? .openGoal : .running
            case .paused:
                self.phase = .paused
            case .ended:
                self.stopAllTimers()
                // Snapshot live metrics now — they are cleared once builder is released.
                let snapshotMetres  = self.totalMetres
                let snapshotSeconds = self.elapsedSeconds
                let snapshotAvgPace = self.avgPaceSecPerKm
                let snapshotAvgHR   = self.avgHeartRate
                let builder         = self.builder
                Task {
                    do {
                        try await builder?.endCollection(at: Date())
                        try await builder?.finishWorkout()
                    } catch {}
                    let calories = builder?
                        .statistics(for: HKQuantityType(.activeEnergyBurned))?
                        .sumQuantity()?
                        .doubleValue(for: .kilocalorie()) ?? 0
                    await MainActor.run {
                        // Only transition if we have not already been dismissed manually.
                        guard self.phase != .inactive else { return }
                        let data = WorkoutSummaryData(
                            totalMetres: snapshotMetres,
                            elapsedSeconds: snapshotSeconds,
                            avgPaceSecPerKm: snapshotAvgPace,
                            avgHeartRate: snapshotAvgHR,
                            calories: calories
                        )
                        self.phase = .summary(data)
                    }
                }
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            self.stopAllTimers()
            self.phase = .failed(error.localizedDescription)
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        for item in data {
            guard let command = try? JSONDecoder().decode(WorkoutMirrorCommand.self, from: item) else { continue }
            Task { @MainActor in
                switch command.kind {
                case .pause:  self.pauseWorkout()
                case .resume: self.resumeWorkout()
                case .end:    self.endWorkout()
                }
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                let stats = workoutBuilder.statistics(for: quantityType)

                switch quantityType {
                case HKQuantityType(.heartRate):
                    if let q = stats?.mostRecentQuantity() {
                        self.heartRate = q.doubleValue(for: HKUnit(from: "count/min"))
                    }
                    if let q = stats?.averageQuantity() {
                        self.avgHeartRate = q.doubleValue(for: HKUnit(from: "count/min"))
                    }

                case HKQuantityType(.distanceWalkingRunning):
                    if let q = stats?.sumQuantity() {
                        self.totalMetres = q.doubleValue(for: .meter())
                        self.checkDistanceStepProgress()
                    }

                case HKQuantityType(.runningSpeed):
                    if let q = stats?.mostRecentQuantity() {
                        let mps = q.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                        self.paceSecPerKm = mps > 0 ? 1000.0 / mps : 0
                    }
                    if let q = stats?.averageQuantity() {
                        let mps = q.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                        self.avgPaceSecPerKm = mps > 0 ? 1000.0 / mps : 0
                    }

                default:
                    break
                }
            }
            self.sendMirrorMessage()
        }
    }

    private func checkDistanceStepProgress() {
        guard currentStepIndex < flatSteps.count else { return }
        let (step, _) = flatSteps[currentStepIndex]
        guard case .distance(let targetMetres) = step.goal else { return }

        let done = totalMetres - stepStartMetres
        let remaining = max(0, targetMetres - done)
        stepProgress = min(done / targetMetres, 1.0)
        stepRemainingText = remaining >= 1000
            ? String(format: "%.1f km", remaining / 1000)
            : "\(Int(remaining.rounded())) m"
        if done >= targetMetres {
            advanceStep()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension WorkoutSessionManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Deactivate our audio session so background audio (podcast, music) resumes at full volume.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - StepKind localized names (Watch app bundle)

private extension StepKind {
    var localizedName: String {
        switch self {
        case .warmup:   String(localized: "Warm-up")
        case .work:     String(localized: "Run")
        case .recovery: String(localized: "Recovery")
        case .cooldown: String(localized: "Cool-down")
        }
    }
}
