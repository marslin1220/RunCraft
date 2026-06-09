import SwiftUI

/// Apple-Workout-style card. One palette drives the tint of the background,
/// the leading icon, and the trailing action button so each card has a
/// strong colour identity — the runner can spot "what kind of workout" at
/// a glance without reading.
///
/// Layout:
///
///   ┌─────────────────────────────────────────┐
///   │ [tinted background]                     │
///   │  [icon]  Title                    [▶]   │
///   │          Subtitle                       │
///   └─────────────────────────────────────────┘
///
/// The trailing slot is a `Trailing` enum — `play` for the dominant
/// "tap to start" affordance, `chevron` for "open / view," `check` for
/// completed sessions, and `none` for read-only rows like rest days.
public struct WorkoutCard<Content: View>: View {
    public let palette: WorkoutCardPalette
    public let symbolName: String
    public let title: String
    public let subtitle: String?
    public let trailing: Trailing
    public let isLoading: Bool
    public let action: () -> Void
    public let secondary: () -> Void
    @ViewBuilder public let accessory: Content

    public init(
        palette: WorkoutCardPalette,
        symbolName: String,
        title: String,
        subtitle: String? = nil,
        trailing: Trailing = .chevron,
        isLoading: Bool = false,
        action: @escaping () -> Void,
        secondary: @escaping () -> Void = {},
        @ViewBuilder accessory: () -> Content = { EmptyView() }
    ) {
        self.palette = palette
        self.symbolName = symbolName
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.isLoading = isLoading
        self.action = action
        self.secondary = secondary
        self.accessory = accessory()
    }

    public enum Trailing {
        /// Dominant CTA — circle, palette tint fill, play icon. Maps to
        /// "this is the next thing you should do."
        case play
        /// Subtle chevron — neutral "open / view" affordance.
        case chevron
        /// Done state.
        case check
        /// Nothing on the right — for rest rows.
        case none
    }

    public var body: some View {
        // Whole card is the primary tap target — opens the workout for
        // editing. The trailing play button has its own tap region so it
        // can fire a different (quick-start) action.
        Button(action: action) {
            HStack(spacing: 14) {
                leadingIcon
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color.brand.textSecondary)
                            .lineLimit(1)
                    }
                    accessory
                }
                Spacer()
                trailingControl
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 76)
            .background(palette.background)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.tint.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var leadingIcon: some View {
        Image(systemName: symbolName)
            .font(.title2)
            .foregroundStyle(palette.tint)
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch trailing {
        case .play:
            Button(action: secondary) {
                ZStack {
                    Circle()
                        .fill(palette.tint)
                        .frame(width: 44, height: 44)
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.black)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.callout.bold())
                            .foregroundStyle(.black)
                            .offset(x: 1) // optical centring inside the circle
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel("Start now")

        case .chevron:
            Image(systemName: "chevron.right")
                .font(.subheadline.bold())
                .foregroundStyle(Color.brand.textSecondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

        case .check:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.brand.success)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

        case .none:
            EmptyView()
        }
    }
}
