import DesignSystem
import SwiftUI
import UIKit

struct HealthPermissionBanner: View {
    let onDismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brand.danger)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Health permission lost")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.brand.textPrimary)
                    Text("RunCraft can no longer read your Health data. HRV, race times and completed-workout sync will stop updating until you re-grant access.")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                }

                Spacer(minLength: 6)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brand.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss health permission alert")
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color.brand.danger)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Settings → Health → Data Access & Devices → RunCraft")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brand.danger.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct VDOTUpgradeBanner: View {
    let upgrade: TrainingPlan.VDOTUpgrade
    let onAccept: () -> Void
    let onDismiss: () -> Void

    private var oldVDOT: String { upgrade.oldVDOT.formatted(.number.precision(.fractionLength(1))) }
    private var newVDOT: String { upgrade.newVDOT.formatted(.number.precision(.fractionLength(1))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brand.accent)
                    .accessibilityHidden(true)
                Text("VDOT improved")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brand.textPrimary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brand.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss VDOT upgrade")
            }

            HStack(spacing: 6) {
                Text(oldVDOT)
                    .foregroundStyle(Color.brand.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.brand.textSecondary)
                    .accessibilityHidden(true)
                Text(newVDOT)
                    .bold()
                    .foregroundStyle(Color.brand.accent)
            }
            .font(.title3.monospacedDigit())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("VDOT improved from \(oldVDOT) to \(newVDOT)")

            Text("Update your training paces to match?")
                .font(.caption)
                .foregroundStyle(Color.brand.textSecondary)

            Button {
                onAccept()
            } label: {
                Text("Update paces")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color.brand.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Updates your pace zones to use the new VDOT")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brand.accent.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct RecoveryAdviceBanner: View {
    let reason: String
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brand.caution)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery looks low today")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.brand.textPrimary)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                    Text("We can swap today's hard session for an easy 5 km run.")
                        .font(.caption)
                        .foregroundStyle(Color.brand.textSecondary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 6)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brand.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss recovery advice")
            }

            Button {
                onApply()
            } label: {
                Text("Swap to Easy")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color.brand.caution)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Replaces today's hard session with an easy 5 km run")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brand.caution.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
