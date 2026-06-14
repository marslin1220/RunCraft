import DesignSystem
import SwiftUI

/// Snippet rendered after `StartWorkoutIntent` runs. Three states cover
/// success / WorkoutKit unavailable / send failed — each gets a distinct
/// icon so the runner can tell what happened at a glance.
public struct StartWorkoutSnippetView: View {
    let workout: WorkoutTemplateEntity
    let status: Status

    public enum Status {
        case sent
        case unavailable
        case failed
    }

    public init(workout: WorkoutTemplateEntity, status: Status) {
        self.workout = workout
        self.status = status
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            workoutCard
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusTint)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusHeadline)
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
                Text(workout.name)
                    .font(.title3.bold())
                    .foregroundStyle(Color.brand.textPrimary)
            }
        }
    }

    private var workoutCard: some View {
        HStack(spacing: 10) {
            Image(systemName: workout.isPreset ? "sparkles" : "figure.run")
                .font(.subheadline)
                .foregroundStyle(Color.brand.accent)
            Text(subtitle)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.brand.textSecondary)
        }
    }

    private var footer: some View {
        Text(footerText)
            .font(.caption)
            .foregroundStyle(Color.brand.textSecondary)
    }

    // MARK: - Status mapping

    private var statusIcon: String {
        switch status {
        case .sent:        "applewatch.radiowaves.left.and.right"
        case .unavailable: "exclamationmark.triangle.fill"
        case .failed:      "xmark.octagon.fill"
        }
    }

    private var statusTint: Color {
        switch status {
        case .sent:        Color.brand.accent
        case .unavailable: Color.brand.caution
        case .failed:      Color.brand.danger
        }
    }

    private var statusHeadline: String {
        switch status {
        case .sent:        "Sent to Apple Watch"
        case .unavailable: "Watch unavailable"
        case .failed:      "Couldn't send"
        }
    }

    private var footerText: String {
        switch status {
        case .sent:        "Open Workouts on your Apple Watch within a minute."
        case .unavailable: "WorkoutKit isn't available on this device."
        case .failed:      "Open RunCraft and try Start Workout from the editor."
        }
    }

    private var subtitle: String {
        workout.summary
    }
}
