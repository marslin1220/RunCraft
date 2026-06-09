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

1. **Pure black + a single, loud accent.** Dark mode is the only mode.
   No light theme. The accent (Electric Lime, `#CCFF00`) carries brand
   identity *and* signals primary action. Every other colour is muted.
2. **Numbers are the content.** Pace, VDOT, distance, days-to-race —
   the screen exists to surface these. Monospaced digits, generous
   contrast, no decoration that competes with the data.

---

## Tokens

All tokens live on `Color.brand.*`. Import `DesignSystem` in any view
file that needs them.

### Surfaces

| Token | Hex | Use for |
|-------|-----|---------|
| `brand.background` | `#000000` | App background, every tab |
| `brand.surface` | `#1A1B2E` | Cards, banners, list rows on the background |
| `brand.surfaceElevated` | `#212138` | One step up — modal sheets if customised |

> **Why not `Color.black` everywhere?** OLED-pure black is right for the
> backdrop, but a single layer of surface (`#1A1B2E`, a near-black with
> a hint of blue) separates *the thing you tap* from *the canvas*.
> Without it, cards disappear visually.

### Text

| Token | Approx contrast on `surface` | Use for |
|-------|------------------------------|---------|
| `brand.textPrimary` (white) | 18:1 | Headlines, primary content |
| `brand.textSecondary` (~74 % white) | ~5:1 (passes WCAG AA) | Captions, helper text, metadata |
| `brand.textTertiary` (~55 % white) | ~3:1 | Disclaimers, watermarks, *non-essential* only |

> **Why not `.secondary`?** SwiftUI's stock `.secondary` resolves to
> ~60 % white on dark, which lands ~3.5 : 1 on pure black — below WCAG
> AA's 4.5 : 1 for body text. `textSecondary` is calibrated to clear
> the bar. Inside `Form` views with grouped backgrounds, stock
> `.secondary` is fine — only swap on raw dark surfaces.

### Accent

| Token | Hex | Use for |
|-------|-----|---------|
| `brand.accent` | `#CCFF00` (Electric Lime) | Primary CTA, focus, "now" markers, VDOT highlights |
| `brand.accentMuted` | `accent` @ 18 % opacity | Chip fills, banner stroke, badge backgrounds |

> **One accent only.** If you find yourself reaching for a second
> brand colour, you're either signalling a state (use a semantic
> token) or a zone (use the zone palette). Two equal-weight accents
> = no accent.

### Semantic

| Token | Hex | Meaning |
|-------|-----|---------|
| `brand.success` | `#4DAF50` | Completed sessions, success badges |
| `brand.caution` | `#FFC107` | Recovery banner, threshold alerts, "watch this" |
| `brand.danger` | `#F44336` | Destructive buttons, error states |

> Pair every semantic colour with an icon or label. WCAG `color-not-only`
> — colour-blind users can't read state from hue alone.

### Pace zones

A five-step ramp from cool/soft to hot/intense. The zone letter
(E / M / T / I / R) is the primary semantic; colour is *visual rhythm*,
not the only channel.

| Token | Approx hue | Zone |
|-------|-----------|------|
| `brand.zone.easy` | muted sage | E — recovery, long runs |
| `brand.zone.marathon` | soft slate-blue | M — marathon pace |
| `brand.zone.threshold` | mustard | T — comfortably hard |
| `brand.zone.interval` | burnt orange | I — VO₂max efforts |
| `brand.zone.repetition` | `accent` lime | R — top-end speed |

> **Why this palette over the previous Material Design swatches?**
> The old `#4CAF50 / #2196F3 / #FFC107 / #FF5722 / #F44336` were five
> independent traffic-lights — visually loud, no relationship to brand.
> The new ramp reads as a *progression*: as effort climbs, colour gets
> warmer and brighter, ending at the brand lime for the hardest zone.
> Ties pace zones into the brand story.

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

- [ ] All body / caption text on dark surface uses `brand.textSecondary` (not `.secondary`)
- [ ] All tappable elements meet 44 × 44 pt
- [ ] Numeric text uses `.monospacedDigit()` so it doesn't jitter
- [ ] Composite rows use `.accessibilityElement(children: .combine)` + a single descriptive `.accessibilityLabel`
- [ ] Decorative SF Symbols use `.accessibilityHidden(true)`
- [ ] Charts encode data on **at least two channels** (colour + shape, or colour + position) — never colour alone
- [ ] Chart legends are visible
- [ ] Destructive buttons use `Color.brand.danger` *and* a `trash` icon *and* `.tint(.red)` if inside `.swipeActions` (the app-wide lime tint bleeds through otherwise)
- [ ] Animations respect `accessibilityReduceMotion`

---

## Anti-patterns

These come up in code review often enough to call out:

- `Color(hex: "#CCFF00")` — use `Color.brand.accent`
- `Color.electricLime` / `Color.workshopLime` — both removed, use `Color.brand.accent`
- Multiple `Color(hex:)` initializers — single canonical one lives in `DesignSystem/Theme.swift`
- `.foregroundStyle(.secondary)` on `Color.black` background — fails WCAG AA, use `Color.brand.textSecondary`
- `font(.system(size: 10, ...))` for body text — below HIG floor, use `.caption2` (and `.monospacedDigit()` if numeric)
- Heavy decorative shadows on primary CTAs (`radius: 12`+) — use shadows for *elevation*, not glow effects
- A second accent colour — there is only `brand.accent`

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
