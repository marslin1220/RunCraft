//
//  WorkoutSessionManager.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/16.
//

import AppleWatchSync
import Combine
import Foundation
import HealthKit
import RunCraftModels

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
    @Published var paceSecPerKm: Double = 0
    @Published var totalMetres: Double = 0
    @Published var stepName: String = ""
    @Published var stepGoalText: String = ""
    @Published var stepProgress: Double = 0

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var flatSteps: [(step: WorkoutStep, displayName: String)] = []
    private var currentStepIndex: Int = 0
    private var stepStartMetres: Double = 0
    private var stepStartDate: Date = Date()

    private var elapsedTimerTask: Task<Void, Never>?
    private var stepTimerTask: Task<Void, Never>?

    func startWorkout(session: HKWorkoutSession, blocks: [WorkoutBlock], healthStore: HKHealthStore) throws {
        self.session = session
        session.delegate = self

        let builder = session.associatedWorkoutBuilder()
        self.builder = builder
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: session.workoutConfiguration)

        flatSteps = flattenBlocks(blocks)
        currentStepIndex = 0

        builder.beginCollection(withStart: Date()) { [weak self] _, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.phase = .failed(error.localizedDescription)
                }
                return
            }
            Task { @MainActor in
                session.startActivity(with: Date())
                self.phase = .running
                self.startElapsedTimer()
                self.updateCurrentStep()
            }
        }
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
            return
        }

        let (step, displayName) = flatSteps[currentStepIndex]
        stepName = displayName
        stepStartMetres = totalMetres
        stepStartDate = Date()
        stepProgress = 0

        switch step.goal {
        case .openEnded:
            stepGoalText = "Open"
        case .distance(let metres):
            stepGoalText = metres >= 1000
                ? String(format: "%.1f km", metres / 1000)
                : "\(Int(metres)) m"
        case .time(let seconds):
            let m = seconds / 60
            let s = seconds % 60
            stepGoalText = s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
            startStepTimer(duration: TimeInterval(seconds))
        }
    }

    private func advanceStep() {
        currentStepIndex += 1
        if currentStepIndex >= flatSteps.count {
            endWorkout()
        } else {
            updateCurrentStep()
        }
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
                self.builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
                    self?.builder?.finishWorkout { _, _ in }
                }
                self.phase = .inactive
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

                default:
                    break
                }
            }
        }
    }

    private func checkDistanceStepProgress() {
        guard currentStepIndex < flatSteps.count else { return }
        let (step, _) = flatSteps[currentStepIndex]
        guard case .distance(let targetMetres) = step.goal else { return }

        let done = totalMetres - stepStartMetres
        stepProgress = min(done / targetMetres, 1.0)
        if done >= targetMetres {
            advanceStep()
        }
    }
}
