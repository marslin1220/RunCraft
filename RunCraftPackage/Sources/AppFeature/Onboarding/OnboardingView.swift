import DesignSystem
import SwiftUI

/// First-launch flow. Four pages walk the runner through what RunCraft
/// is, the Daniels VDOT science, the Apple Watch handoff, and the Siri
/// integration — then hand off to the Plan tab where the race-goal
/// setup prompt takes over.
///
/// Pure SwiftUI (no TCA) — the flow is local UI state plus a single
/// AppStorage write at completion. Triggered by `AppView` via
/// `.fullScreenCover` while `hasCompletedOnboarding == false`.
public struct OnboardingView: View {
    @State private var page: Int = 0
    let onComplete: () -> Void

    private let totalPages = 4

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    vdotPage.tag(1)
                    watchPage.tag(2)
                    siriPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)

                pageIndicator
                primaryButton
            }
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            Spacer()
            if page < totalPages - 1 {
                Button(action: complete) {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.brand.textSecondary)
                }
                .padding(.trailing, 20)
                .padding(.top, 12)
                .accessibilityLabel("Skip onboarding")
            }
        }
        .frame(height: 44)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPage(
            symbol: "figure.run.circle.fill",
            title: Text("Welcome to RunCraft"),
            tagline: Text("Train with the science"),
            body: Text("Periodised plans, real Apple Watch dispatch, and Siri-driven control — everything a serious runner needs in one app.")
        )
    }

    private var vdotPage: some View {
        OnboardingPage(
            symbol: "speedometer",
            title: Text("Built on VDOT"),
            tagline: Text("Forty years of Jack Daniels' coaching"),
            body: Text("Enter a race time — or let HealthKit pull your best — and RunCraft derives your five training pace zones from the Daniels formula.")
        )
    }

    private var watchPage: some View {
        OnboardingPage(
            symbol: "applewatch.radiowaves.left.and.right",
            title: Text("One tap to your wrist"),
            tagline: Text("WorkoutKit handoff"),
            body: Text("Send any workout to your paired Apple Watch with a single button. Pace alerts run on-wrist — no menu hunting mid-stride.")
        )
    }

    private var siriPage: some View {
        OnboardingPage(
            symbol: "waveform.circle.fill",
            title: Text("Just ask Siri"),
            tagline: Text("Voice-first control"),
            body: Text("\"What's today's training?\" · \"Start Yasso 800.\" · \"Set my VDOT to 52.\" RunCraft answers, dispatches, and saves.")
        )
    }

    // MARK: - Bottom controls

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { idx in
                Circle()
                    .fill(idx == page ? Color.brand.accent : Color.brand.textSecondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: page)
            }
        }
        .padding(.bottom, 24)
        .accessibilityHidden(true)
    }

    private var primaryButton: some View {
        Button(action: advance) {
            Text(isLastPage ? "Get started" : "Next")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brand.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    private var isLastPage: Bool { page >= totalPages - 1 }

    private func advance() {
        if isLastPage {
            complete()
        } else {
            page += 1
        }
    }

    private func complete() {
        onComplete()
    }
}

// MARK: - Page layout

/// Shared layout for the four onboarding pages. Hero icon at the top,
/// then a stack of headline / tagline / body text. Pure SwiftUI, no
/// state — the parent owns paging.
///
/// The descriptive text parameter is `bodyText` (not `body`) so it
/// doesn't shadow SwiftUI's protocol requirement.
private struct OnboardingPage: View {
    let symbol: String
    let title: Text
    let tagline: Text
    let bodyText: Text

    init(symbol: String, title: Text, tagline: Text, body: Text) {
        self.symbol = symbol
        self.title = title
        self.tagline = tagline
        self.bodyText = body
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            Image(systemName: symbol)
                .font(.system(size: 96, weight: .light))
                .foregroundStyle(Color.brand.accent)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                title
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.brand.textPrimary)
                    .multilineTextAlignment(.center)

                tagline
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.brand.accent)
                    .multilineTextAlignment(.center)
            }

            bodyText
                .font(.body)
                .foregroundStyle(Color.brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
