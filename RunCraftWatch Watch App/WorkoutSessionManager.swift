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

    enum Phase: Equatable {
        case inactive
        case running
        case paused
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

    private var previousStepDisplayName: String = ""
    private let speechSynthesizer = AVSpeechSynthesizer()

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var flatSteps: [(step: WorkoutStep, displayName: String)] = []
    private var currentStepIndex: Int = 0
    private var stepStartMetres: Double = 0
    private var stepStartDate: Date = Date()

    private var elapsedTimerTask: Task<Void, Never>?
    private var stepTimerTask: Task<Void, Never>?

    func startWorkout(session: HKWorkoutSession, blocks: [WorkoutBlock], healthStore: HKHealthStore) async throws {
        self.session = session
        session.delegate = self

        let builder = session.associatedWorkoutBuilder()
        self.builder = builder
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: session.workoutConfiguration)

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

        phase = .running
        startElapsedTimer()
        updateCurrentStep()
    }

    func endWorkout() {
        session?.end()
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
                result.append((s, s.kind.displayName))
            case .repeatGroup(let g):
                let n = g.iterations
                for i in 1...max(1, n) {
                    for s in g.steps {
                        let label = n > 1 ? "Rep \(i)/\(n) · \(s.kind.displayName)" : s.kind.displayName
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

        // Voice + haptic announcement
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
            endWorkout()
        } else {
            updateCurrentStep()
        }
    }

    private func announceStep(name: String, goal: String, previous: String) {
        WKInterfaceDevice.current().play(.notification)
        let voiceName = name.replacingOccurrences(of: " · ", with: " ")
        let text: String
        if previous.isEmpty {
            text = "\(voiceName). Goal: \(goal)."
        } else {
            let voicePrev = previous.replacingOccurrences(of: " · ", with: " ")
            text = "\(voicePrev) complete. \(voiceName). Goal: \(goal)."
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }

    private func announceWorkoutComplete() {
        WKInterfaceDevice.current().play(.success)
        let voicePrev = previousStepDisplayName.replacingOccurrences(of: " · ", with: " ")
        let text = voicePrev.isEmpty
            ? "Workout complete!"
            : "\(voicePrev) complete. Workout complete!"
        let utterance = AVSpeechUtterance(string: text)
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
                self.phase = .running
            case .paused:
                self.phase = .paused
            case .ended:
                self.stopAllTimers()
                self.phase = .inactive
                let builder = self.builder
                Task {
                    do {
                        try await builder?.endCollection(at: Date())
                        try await builder?.finishWorkout()
                    } catch {}
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
