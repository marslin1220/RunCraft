#if DEBUG
import SwiftUI

/// Renderable App Icon mock — open this file in Xcode, expand the
/// canvas preview, and right-click → "Export Preview…" to save as PNG.
/// Three previews at the bottom produce the three variants the asset
/// catalog needs (Standard / Dark / Tinted).
///
/// Geometry knobs are all up top so the look stays adjustable without
/// hunting through the body:
/// - `ringDiameter`  controls the outer size of the ring
/// - `ringStroke`    controls how thick it is
/// - `gapDegrees`    controls the size of the "uncompleted" arc at 12 o'clock
/// - `runnerSize`    controls the central figure.run symbol
///
/// `Circle().trim(from:to:)` is the trick that produces the 80% feel —
/// 0.0 → 1.0 is one full revolution, so trimming away a slice at the
/// top leaves the visible progress arc. The angular gradient makes one
/// end faint and the other saturated, reading as "training accumulates."
struct AppIconView: View {
    enum Variant {
        case standard   // black bg, cyan ring, white figure
        case dark       // same as standard (we're already on black)
        case tinted     // grayscale — iOS applies the user's accent
    }
    let variant: Variant

    // MARK: - Tunable geometry

    private let canvas: CGFloat        = 1024
    private let ringDiameter: CGFloat  = 720
    private let ringStroke: CGFloat    = 85    // HIG: thinner than before — gives the runner more breathing room
    private let gapDegrees: CGFloat    = 54    // ~85% complete — "almost there" feel without looking unfinished
    private let runnerSize: CGFloat    = 380   // figure.run point size
    private let runnerYOffset: CGFloat = -20   // HIG: optical centering — circular elements feel centred when nudged up ~2%

    // MARK: - Derived

    private var trimStart: CGFloat { (gapDegrees / 2) / 360 }
    private var trimEnd:   CGFloat { 1 - (gapDegrees / 2) / 360 }

    /// Solid cyan in standard / dark — gradient was inconsistent across
    /// sizes (HIG: simpler reads better at 29×29 settings icon). Tinted
    /// uses pure white so iOS applies its accent cleanly.
    private var ringColor: Color {
        switch variant {
        case .standard, .dark: Color(red: 0.00, green: 0.831, blue: 1.00)
        case .tinted:          .white
        }
    }
    private var runnerColor: Color {
        switch variant {
        case .standard, .dark: .white
        case .tinted:          Color(white: 0.85)   // slightly off-white so iOS tint adds contrast vs the ring
        }
    }
    private var backgroundColor: Color {
        switch variant {
        case .standard, .dark: .black
        case .tinted:          .black   // tinted variant is also on black, iOS tints the foreground
        }
    }

    var body: some View {
        ZStack {
            backgroundColor

            Circle()
                .trim(from: trimStart, to: trimEnd)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))   // 0% lives at 12 o'clock
                .frame(width: ringDiameter, height: ringDiameter)

            Image(systemName: "figure.run")
                .font(.system(size: runnerSize, weight: .regular))
                .foregroundStyle(runnerColor)
                .offset(y: runnerYOffset)
        }
        .frame(width: canvas, height: canvas)
    }
}

// MARK: - Previews
//
// Each preview is exactly 1024×1024. In Xcode:
//   1. Open this file
//   2. Expand the canvas (Editor → Canvas)
//   3. Right-click a preview → "Export Preview…" → save as PNG
//
// Naming convention to match the asset catalog hook-up step:
//   icon-light.png   ← Standard variant
//   icon-dark.png    ← Dark variant
//   icon-tinted.png  ← Tinted variant

#Preview("Standard (light)", traits: .fixedLayout(width: 1024, height: 1024)) {
    AppIconView(variant: .standard)
}

#Preview("Dark", traits: .fixedLayout(width: 1024, height: 1024)) {
    AppIconView(variant: .dark)
}

#Preview("Tinted", traits: .fixedLayout(width: 1024, height: 1024)) {
    AppIconView(variant: .tinted)
}
#endif
