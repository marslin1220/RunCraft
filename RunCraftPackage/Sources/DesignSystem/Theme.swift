import SwiftUI

/// RunCraft's design tokens. Use these instead of raw hex values so the
/// palette can evolve in one place and so audits / theming stay sane.
///
/// Naming follows Material's semantic-role convention (surface / on-surface
/// / accent) rather than literal colour names — `Color.brand.accent` will
/// keep its meaning even if the brand colour shifts.
public extension Color {
    enum brand {

        // MARK: - Surfaces

        /// App background. Pure black for OLED contrast and brand identity.
        public static let background = Color.black

        /// Raised surface — cards, banners, list rows on the dark background.
        public static let surface = Color(red: 0.10, green: 0.10, blue: 0.18) // #1A1B2E

        /// One step further raised (modal sheets, popovers if customised).
        public static let surfaceElevated = Color(red: 0.13, green: 0.13, blue: 0.22)

        // MARK: - Text

        /// Primary text on dark surfaces. Pure white for max contrast.
        public static let textPrimary = Color.white

        /// Secondary text on dark surfaces. **~74 % white** — passes WCAG AA
        /// (4.5:1) against `background` and `surface`. iOS's stock
        /// `.secondary` resolves to ~60 % which lands ~3.5:1 on pure black,
        /// below AA. Use this token for captions, helper text, metadata.
        public static let textSecondary = Color(white: 0.74)

        /// Tertiary text — disclaimers, watermarks, fine print. Around 3:1
        /// against the surface, acceptable only for non-essential decoration.
        public static let textTertiary = Color(white: 0.55)

        // MARK: - Accent

        /// Brand accent (Electric Lime). Primary CTAs, focus, "now" markers,
        /// VDOT highlights, progress.
        public static let accent = Color(red: 0.80, green: 1.00, blue: 0.00) // #CCFF00

        /// Same hue at low alpha, for tinted backgrounds (chip fills,
        /// banner borders).
        public static let accentMuted = accent.opacity(0.18)

        // MARK: - Semantic

        /// Positive confirmation (completed workouts, success badges).
        public static let success = Color(red: 0.30, green: 0.69, blue: 0.31)

        /// Caution (recovery banner, threshold alerts).
        public static let caution = Color(red: 1.00, green: 0.76, blue: 0.03)

        /// Destructive (delete buttons, errors).
        public static let danger = Color(red: 0.96, green: 0.26, blue: 0.21)

        // MARK: - Pace zones
        //
        // Five-step ramp from cool/soft (easy) to hot/intense (repetition).
        // Letter labels carry the meaning — colour is a visual rhythm cue,
        // not the only channel, so the palette can be quieter than the
        // earlier Material swatches without losing semantics.

        public enum zone {
            public static let easy       = Color(red: 0.66, green: 0.71, blue: 0.63) // muted sage
            public static let marathon   = Color(red: 0.60, green: 0.71, blue: 0.80) // soft slate-blue
            public static let threshold  = Color(red: 0.83, green: 0.77, blue: 0.37) // mustard
            public static let interval   = Color(red: 0.91, green: 0.57, blue: 0.42) // burnt orange
            public static let repetition = Color(red: 0.80, green: 1.00, blue: 0.00) // accent lime
        }
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
