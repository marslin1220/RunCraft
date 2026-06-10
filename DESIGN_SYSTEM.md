# RunCraft Design System

> Single source of truth for visual decisions. Tokens live in
> `RunCraftPackage/Sources/DesignSystem/Theme.swift` — this doc explains
> *why* each token exists, when to use it, and what the underlying HIG
> / WCAG rule is. If a value here disagrees with the code, the code wins
> and this doc needs updating.

## North star

RunCraft is an instrument for serious runners following a 16-week
periodised Jack Daniels plan. The visual language should read as
**athletic, technical, OLED-native** — not playful, not corporate.

Two opinions drive everything below:

1. **Pure black + a single, loud accent.** Dark mode is the primary mode
   (light mode support tracked separately — see "Theme variants"). The
   accent (Electric Cyan, `#00D4FF`) carries brand identity *and* signals
   primary action. Every other colour is muted. Cyan was chosen over
   Apple Workout's signature lime to read as "instrument / precision"
   rather than "generic fitness app."
2. **Numbers are the content.** Pace, VDOT, distance, days-to-race —
   the screen exists to surface these. Monospaced digits, generous
   contrast, no decoration that competes with the data.

---

## Theme variants

Every `Color.brand.*` token resolves dynamically per
`UIUserInterfaceStyle`. SwiftUI picks the right value when the system
theme changes — no view-level branching needed. The implementation
uses `UIColor(dynamicProvider:)` wrapped as a `Color`, so the same
property reference returns the light or dark hex.

Views must **not** apply `.preferredColorScheme(.dark)` any more —
let the system propagate the user's choice.

## Tokens

All tokens live on `Color.brand.*`. Import `DesignSystem` in any view
file that needs them.

### Surfaces

| Token | Light | Dark | Use for |
|-------|-------|------|---------|
| `brand.background` | `#F2F2F7` | `#000000` | App background, every tab |
| `brand.surface` | `#FFFFFF` | `#1A1B2E` | Cards, banners, list rows on the background |
| `brand.surfaceElevated` | `#FFFFFF` | `#212138` | One step up — modal sheets if customised |

> **Why not pure white as `background` in light?** Pure-white edges
> look harsh next to white surface cards — the cards disappear
> visually. iOS's `systemGroupedBackground` is a soft warm grey
> (~`#F2F2F7`) for exactly this reason; we mirror that.
>
> **Why `#1A1B2E` in dark?** OLED-pure black is right for the
> backdrop, but a single layer of surface (near-black with a hint of
> blue) separates *the thing you tap* from *the canvas*.

### Text

| Token | Light | Dark | Notes |
|-------|-------|------|-------|
| `brand.textPrimary` | `#1C1C1E` | `#FFFFFF` | Headlines, primary content. AA on both surfaces. |
| `brand.textSecondary` | `#6B6B72` | ~74 % white | Captions, helper text. Calibrated for ≥4.5:1 (WCAG AA) on *both* surfaces. |
| `brand.textTertiary` | `#8E8E93` | ~55 % white | Disclaimers, watermarks, *non-essential* only — ~3:1. |

> **Why not `.secondary`?** SwiftUI's stock `.secondary` resolves to
> ~60 % white on dark, which lands ~3.5 : 1 on pure black — below WCAG
> AA's 4.5 : 1 for body text. `textSecondary` is calibrated to clear
> the bar in both modes. Inside `Form` views with grouped backgrounds,
> stock `.secondary` is fine — only swap on raw brand surfaces.

### Accent

| Token | Light | Dark | Use for |
|-------|-------|------|---------|
| `brand.accent` | `#0099CC` | `#00D4FF` (Electric Cyan) | Primary CTA, focus, "now" markers, VDOT highlights |
| `brand.accentMuted` | `accent` @ 18 % | `accent` @ 18 % | Chip fills, banner stroke, badge backgrounds |

> **Why two cyans?** `#00D4FF` is too bright on white — pure cyan
> text on white background lands ~2.5 : 1 (fails AA). The light-mode
> variant `#0099CC` keeps the cyan-ness while clearing AA on white.
> In dark mode the brighter cyan is correct.
>
> **Button text colour**: black in both modes. Black-on-cyan reads at
> 11 : 1 (dark) and 5.8 : 1 (light) — both well above the threshold.

> **Why cyan, not lime?** Apple's Workout app already owns lime
> (`#B7FF40`) as a sports-app accent. Cyan keeps the OLED-friendly
> high saturation while reading as "instrument / data" — closer to a
> Garmin readout than a fitness tracker.
>
> **One accent only.** If you find yourself reaching for a second
> brand colour, you're either signalling a state (use a semantic
> token) or a zone (use the zone palette). Two equal-weight accents
> = no accent.

### Semantic

| Token | Light | Dark | Meaning |
|-------|-------|------|---------|
| `brand.success` | `#2E7D32` | `#4DAF50` | Completed sessions, success badges |
| `brand.caution` | `#E65100` | `#FFC107` | Recovery banner, threshold alerts, "watch this" |
| `brand.danger` | `#C62828` | `#F44336` | Destructive buttons, error states |

> **Why caution swaps hue in light mode?** Amber (`#FFC107`) fails AA
> on white text (1.7 : 1). The deep orange (`#E65100`) keeps the
> "watch this" semantic — same place in the warm half of the spectrum
> — while clearing AA. Pair every semantic colour with an icon or
> label regardless. WCAG `color-not-only` — colour-blind users can't
> read state from hue alone.

### Pace zones

A five-step ramp from cool/soft to hot/intense. The zone letter
(E / M / T / I / R) is the primary semantic; colour is *visual rhythm*,
not the only channel.

| Token | Light | Dark | Zone |
|-------|-------|------|------|
| `brand.zone.easy` | `#2E7D32` (forest) | muted sage | E — recovery, long runs |
| `brand.zone.marathon` | `#1565C0` (deep blue) | soft slate-blue | M — marathon pace |
| `brand.zone.threshold` | `#C68200` (dark amber) | mustard | T — comfortably hard |
| `brand.zone.interval` | `#D32F2F` (deep red) | burnt orange | I — VO₂max efforts |
| `brand.zone.repetition` | `#B71C1C` (deeper red) | fire red | R — top-end speed |

> **Why two palettes?** The dark-mode hues are mid-saturation tones
> calibrated for OLED black — they fail AA contrast on white. Light
> mode darkens each hue independently while preserving the cool→warm
> progression. The heat ramp deliberately doesn't end at the cyan
> brand accent in either mode — mixing cool brand into a warm pace
> progression would break the intensity-as-heat metaphor.

---

## Typography

We don't ship custom fonts. SF Pro variants only.

| Role | SwiftUI font | Notes |
|------|--------------|-------|
| Display digit (countdown ring, VDOT card) | `.system(size: 48, weight: .bold, design: .rounded)` | Rounded reads as "athletic instrument" |
| Headline (week header, banner title) | `.headline` | Auto-scales with Dynamic Type |
| Body | `.body` / `.subheadline` | Default — never override size |
| Caption (helper text, day labels) | `.caption` / `.caption2` | Pair with `Color.brand.textSecondary` |
| **Numbers** | append `.monospacedDigit()` | Locks digit widths — pace `5:30 → 5:31` doesn't jitter |

### Baseline alignment with display digits

Rounded display digits (`.system(size: 36+, design: .rounded)`) have **tall
ascenders** that throw off SwiftUI's default `.firstTextBaseline` HStack
alignment when placed next to caption-sized labels. Mathematically the
baselines match; visually the big number floats above its captions.

Use `HStack(alignment: .center, …)` whenever a display digit shares a row
with a smaller caption block. Examples: Insights fitness-trend hero
(`30  VDOT / Drives your plan`), Plan tab countdown HStack
(`120pt ring  / Goal name / phase / date`).

### Dynamic Type

- **Headlines, body, captions:** rely on `.headline` / `.body` /
  `.caption` and let iOS scale.
- **Display numbers:** the only place we use `.system(size:)` is the
  countdown digit and the Current-VDOT card. These are visually
  load-bearing; we accept they don't scale and rely on the
  `accessibilityLabel` on the parent for VoiceOver users.

---

## Layout

### Spacing

8 pt rhythm. Common values: 4, 8, 12, 16, 20, 24.

| Use | Value |
|-----|-------|
| Inline gap inside a row (icon ↔ text) | 8 |
| Card internal padding | 12–16 |
| Vertical rhythm between cards in a tab | 16–24 |
| Section gap inside a Form | iOS default |

### Touch targets

**44 × 44 pt minimum** — HIG `touch-target-size`, no exceptions.

- Buttons inside cards: `.frame(minHeight: 44)` + `.contentShape(Rectangle())`
- Icon-only dismiss buttons (banner ×): wrap symbol in
  `.frame(width: 44, height: 44).contentShape(Rectangle())`
- Toolbar items: SwiftUI handles this when you use `ToolbarItem`

### Safe areas

Floating CTAs (`Start Workout`) should use `.safeAreaInset(edge: .bottom)`
rather than manual `Spacer().frame(height: 100)` — the system handles
home-indicator inset for free.

### Cards

Standard pattern:

```swift
.padding(12)                         // or 14–16 for top-level banners
.background(Color.brand.surface)
.clipShape(RoundedRectangle(cornerRadius: 12))
// Optional brand border:
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.brand.accent.opacity(0.4), lineWidth: 1)
)
```

Corner radius vocabulary: **12 pt** for list cards, **14 pt** for top-level banners (recovery, VDOT upgrade), **16 pt** for the pace-zone summary.

---

## Motion

### Duration

| Kind | Target | Why |
|------|--------|-----|
| State change (tap feedback, toggle) | 100–200 ms | HIG `tap-feedback-speed` |
| Disclosure (collapse/expand) | 200 ms | Tight, doesn't slow scrolling |
| Cross-screen ring/bar reveal | 300 ms ease-out | Visible without being slow |
| Anything over 400 ms | reconsider | HIG `duration-timing` cap |

### Reduced Motion

Every animation that **isn't** a tap feedback must respect
`accessibilityReduceMotion`:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
.animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: someValue)
```

### Easing

- **Enter / appear:** `.easeOut` (slows toward rest)
- **Exit / dismiss:** `.easeIn` (accelerates away) — ~60–70 % of enter duration
- **Toggle:** `.easeInOut`
- **Avoid** `.linear` for UI — feels mechanical

---

## Accessibility checklist

Before shipping a new view, verify:

- [ ] All body / caption text on brand surface uses `brand.textSecondary` (not `.secondary`)
- [ ] No view applies `.preferredColorScheme(.dark)` — system theme wins
- [ ] Visual check in **both** light and dark mode (Xcode preview variants or simulator toggle)
- [ ] All tappable elements meet 44 × 44 pt
- [ ] Numeric text uses `.monospacedDigit()` so it doesn't jitter
- [ ] Composite rows use `.accessibilityElement(children: .combine)` + a single descriptive `.accessibilityLabel`
- [ ] Decorative SF Symbols use `.accessibilityHidden(true)`
- [ ] Charts encode data on **at least two channels** (colour + shape, or colour + position) — never colour alone
- [ ] Chart legends are visible
- [ ] Destructive buttons use `Color.brand.danger` *and* a `trash` icon *and* `.tint(.red)` if inside `.swipeActions` (the app-wide accent tint bleeds through otherwise)
- [ ] Animations respect `accessibilityReduceMotion`

---

## Anti-patterns

These come up in code review often enough to call out:

- `Color(hex: "#00D4FF")` — use `Color.brand.accent`
- `Color(hex: "#CCFF00")` (the old lime) — use `Color.brand.accent`. The
  brand switched from lime to cyan; any leftover lime hex is wrong.
- `Color.electricLime` / `Color.workshopLime` — both removed, use `Color.brand.accent`
- Multiple `Color(hex:)` initializers — single canonical one lives in `DesignSystem/Theme.swift`
- `.foregroundStyle(.secondary)` on `Color.black` background — fails WCAG AA, use `Color.brand.textSecondary`
- `font(.system(size: 10, ...))` for body text — below HIG floor, use `.caption2` (and `.monospacedDigit()` if numeric)
- Heavy decorative shadows on primary CTAs (`radius: 12`+) — use shadows for *elevation*, not glow effects
- A second accent colour — there is only `brand.accent`
- `HStack(alignment: .firstTextBaseline)` pairing a 36pt+ rounded display digit with caption text — use `.center` (see "Baseline alignment with display digits" above)
- Swipe-to-page navigation between peer data views (e.g. VDOT / VO₂max / Δ) — use a segmented `Picker` so all options are visible at once. Swipe hides options and suits social/media, not instrument UI.

---

## Adding a new token

If you reach for a colour or font that isn't on the list:

1. Ask: is this *really* a new semantic, or can `brand.accent` /
   `brand.surface` / a semantic colour handle it?
2. If yes, add it to `DesignSystem/Theme.swift` with a documentation
   comment explaining the role.
3. Update this doc.
4. Make a separate commit so the design change is reviewable
   independent of the feature that prompted it.
