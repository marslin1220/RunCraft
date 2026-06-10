import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// RunCraft's design tokens. Use these instead of raw hex values so the
/// palette can evolve in one place and so audits / theming stay sane.
///
/// Naming follows Material's semantic-role convention (surface / on-surface
/// / accent) rather than literal colour names — `Color.brand.accent` will
/// keep its meaning even if the brand colour shifts.
///
/// Every token resolves dynamically per `UIUserInterfaceStyle`, so a single
/// `Color.brand.surface` lookup gives the right value in both light and
/// dark mode. The light values are tuned to keep contrast against
/// `textPrimary` ≥ 4.5 : 1 (WCAG AA) without dropping below 3 : 1 for
/// decorative borders. Dark values are unchanged from the original OLED
/// palette.
public extension Color {
    enum brand {

        // MARK: - Surfaces

        /// App background. Pure black for OLED in dark mode; soft warm grey
        /// (iOS systemGroupedBackground equivalent) in light mode.
        public static let background = Color.dynamicBrand(
            light: Color(red: 0.949, green: 0.949, blue: 0.969), // #F2F2F7
            dark:  .black
        )

        /// Raised surface — cards, banners, list rows on the background.
        public static let surface = Color.dynamicBrand(
            light: .white,
            dark:  Color(red: 0.10, green: 0.10, blue: 0.18) // #1A1B2E
        )

        /// One step further raised (modal sheets, popovers if customised).
        public static let surfaceElevated = Color.dynamicBrand(
            light: .white,
            dark:  Color(red: 0.13, green: 0.13, blue: 0.22)
        )

        // MARK: - Text

        /// Primary text on `surface` / `background`. Near-black on light,
        /// pure white on dark.
        public static let textPrimary = Color.dynamicBrand(
            light: Color(red: 0.11, green: 0.11, blue: 0.12), // #1C1C1E
            dark:  .white
        )

        /// Secondary text — captions, helper text, metadata. Calibrated for
        /// WCAG AA (≥ 4.5:1) against both light and dark surfaces.
        public static let textSecondary = Color.dynamicBrand(
            light: Color(red: 0.42, green: 0.42, blue: 0.45), // ~iOS systemSecondary
            dark:  Color(white: 0.74)
        )

        /// Tertiary text — disclaimers, watermarks, fine print. Around
        /// 3:1 on its surface; non-essential only.
        public static let textTertiary = Color.dynamicBrand(
            light: Color(red: 0.56, green: 0.56, blue: 0.58),
            dark:  Color(white: 0.55)
        )

        // MARK: - Accent

        /// Brand accent (Electric Cyan in dark mode, slightly darkened in
        /// light mode for contrast on white surfaces). Used on primary CTAs,
        /// focus, "now" markers, VDOT highlights, progress.
        public static let accent = Color.dynamicBrand(
            light: Color(red: 0.00, green: 0.60, blue: 0.80), // #0099CC — passes AA on white
            dark:  Color(red: 0.00, green: 0.831, blue: 1.00) // #00D4FF
        )

        /// Same hue at low alpha, for tinted backgrounds (chip fills,
        /// banner borders).
        public static let accentMuted = accent.opacity(0.18)

        // MARK: - Semantic

        /// Positive confirmation (completed workouts, success badges).
        public static let success = Color.dynamicBrand(
            light: Color(red: 0.18, green: 0.49, blue: 0.20), // #2E7D32
            dark:  Color(red: 0.30, green: 0.69, blue: 0.31)
        )

        /// Caution (recovery banner, threshold alerts). Amber fails AA on
        /// white text — light mode swaps to a deep orange to keep the
        /// "watch this" semantic without losing contrast.
        public static let caution = Color.dynamicBrand(
            light: Color(red: 0.90, green: 0.32, blue: 0.00), // #E65100
            dark:  Color(red: 1.00, green: 0.76, blue: 0.03)
        )

        /// Destructive (delete buttons, errors).
        public static let danger = Color.dynamicBrand(
            light: Color(red: 0.78, green: 0.16, blue: 0.16), // #C62828
            dark:  Color(red: 0.96, green: 0.26, blue: 0.21)
        )

        // MARK: - Pace zones
        //
        // Same hex in both modes — pace-zone colours are used at low alpha
        // as card backgrounds with `textPrimary` overlaid, and as small
        // letter labels (E / M / T / I / R). The mid-saturation values
        // here read well against both white and black surfaces.

        public enum zone {
            public static let easy       = Color(red: 0.66, green: 0.71, blue: 0.63)
            public static let marathon   = Color(red: 0.60, green: 0.71, blue: 0.80)
            public static let threshold  = Color(red: 0.83, green: 0.77, blue: 0.37)
            public static let interval   = Color(red: 0.91, green: 0.57, blue: 0.42)
            public static let repetition = Color(red: 1.00, green: 0.24, blue: 0.00)
        }
    }

    /// Internal helper for resolving a Color per `UIUserInterfaceStyle`.
    /// Falls back to the dark variant on macOS where UIKit's trait system
    /// isn't available (we ship on iOS first; macOS is preview-only).
    fileprivate static func dynamicBrand(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            switch trait.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #else
        return dark
        #endif
    }
}

/// Convenience hex initializer for the few cases tokens don't yet cover.
/// Prefer the `Color.brand.*` tokens for anything design-system related.
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Workout-card palette
//
// The Apple Workout app gives every card its own *colour identity* —
// a low-alpha tinted background, a saturated icon, and a play button
// in the same hue. We model that as a struct so call-sites pick one
// palette and pass it down instead of plumbing three separate colours.

public struct WorkoutCardPalette: Sendable {
    public let tint: Color           // saturated — icon + play button
    public let background: Color     // tint @ low alpha — card fill

    public init(tint: Color, alpha: Double = 0.18) {
        self.tint = tint
        self.background = tint.opacity(alpha)
    }
}

public extension WorkoutCardPalette {
    static let easy       = WorkoutCardPalette(tint: Color(red: 0.30, green: 0.69, blue: 0.31))   // green
    static let marathon   = WorkoutCardPalette(tint: Color(red: 0.13, green: 0.59, blue: 0.95))   // blue
    static let threshold  = WorkoutCardPalette(tint: Color(red: 1.00, green: 0.76, blue: 0.03))   // amber
    static let interval   = WorkoutCardPalette(tint: Color(red: 0.96, green: 0.26, blue: 0.21))   // red
    static let repetition = WorkoutCardPalette(tint: Color(red: 1.00, green: 0.34, blue: 0.13))   // orange
    static let long       = WorkoutCardPalette(tint: Color(red: 0.40, green: 0.49, blue: 0.92))   // indigo
    static let rest       = WorkoutCardPalette(tint: Color(white: 0.50), alpha: 0.10)              // grey
    /// Brand palette — Electric Cyan. Used for user-created workouts so they
    /// stand out against the muted preset palette.
    static let brand      = WorkoutCardPalette(tint: Color(red: 0.00, green: 0.831, blue: 1.00))   // #00D4FF
    /// Legacy alias for the brand palette — new code should use `.brand`.
    static let lime       = brand
    static let lilac      = WorkoutCardPalette(tint: Color(red: 0.65, green: 0.51, blue: 0.92))   // for Templates
}
