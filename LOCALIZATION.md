# Localization Plan

This file is the source of truth for RunCraft's multi-language strategy.
First locale is **Traditional Chinese (zh-Hant)**, mirroring Apple's
Taiwan localization conventions where they exist (e.g. the Watch's
Workouts app is "體能訓練" in Apple's own zh-Hant build).

The doc is in three parts:

1. **Glossary (zh-Hant ↔ English)** — domain terminology mapping
2. **Do-not-translate list** — terms that stay in English regardless of locale
3. **Implementation plan** — how iOS / SwiftUI / SPM / App Intents wire up

---

## 1. Glossary (English → 正體中文)

Terms grouped by domain, mirroring `UBIQUITOUS_LANGUAGE.md`. The
Traditional Chinese choices favour idiomatic Taiwan running-culture
vocabulary (e.g. 配速 over 步速, 間歇 over 衝刺間隔).

### 1.1 Training science

| English          | 正體中文         | Notes |
| ---------------- | ---------------- | ----- |
| Pace             | 配速             | Standard TW term — sec/km. |
| Pace Zone        | 配速區間         | The container. "區間" reads more technical than "區域". |
| Pace Range       | 配速範圍         | The min/max bound. |
| Easy             | 輕鬆跑           | Daniels' E zone. |
| Marathon         | 馬拉松配速       | Daniels' M zone. |
| Threshold        | 乳酸閾值         | Daniels' T zone. 跑圈統一用法。Avoid「臨界值」（太抽象）. |
| Interval         | 間歇             | Daniels' I zone. UI 標題 "間歇跑". |
| Repetition       | 反覆衝刺         | Daniels' R zone. 跑圈常用「反覆」or「速度反覆」. |
| Long Run         | 長距離跑         | Aka LSD = Long Slow Distance — 跑圈常直接用 LSD. |
| Recovery Run     | 恢復跑           | Same usage in TW running. |
| Heart Rate       | 心率             | "心跳率" is fine but 心率 is more concise. |
| Heart Rate Zone  | 心率區間         | Same convention as 配速區間. |

### 1.2 Race plan lifecycle

| English          | 正體中文         | Notes |
| ---------------- | ---------------- | ----- |
| Race Goal        | 比賽目標         | |
| Training Plan    | 訓練計畫         | Use 計畫 per user decision (see §4). |
| Training Phase   | 訓練階段         | |
| Base             | 基礎期           | Phase 1 — aerobic base. |
| Build            | 進階期           | Phase 2 — adding intensity. "建立期" is too literal. |
| Peak             | 巔峰期           | Phase 3. |
| Taper            | 減量期           | Phase 4. Standard TW running term. |
| Training Week    | 訓練週           | Or「課表週次」for verbosity. |
| Planned Session  | 預定訓練         | "預定" 比 "計劃中" 更清楚是 schedule-side. |
| Session Type     | 訓練類型         | |
| Completed Workout| 完成的訓練       | 已完成 also fine. |
| This Week        | 本週             | Plan tab section heading. |
| Today            | 今天             | |
| Days until race  | 距離比賽 X 天   | "X days" — render-time interpolation. |

### 1.3 Workout composition

| English          | 正體中文         | Notes |
| ---------------- | ---------------- | ----- |
| Workout          | 訓練             | Bare "workout" — qualify per ubiquitous-language rule. |
| Workout Template | 訓練模板         | Reusable design. |
| Workout Block    | 訓練區塊         | The container. |
| Workout Step     | 訓練步驟         | The leaf. |
| Repeat Group     | 重複組           | "組" reads natural for runners. |
| Step Kind        | 步驟類型         | |
| Warm-up          | 暖身             | |
| Work             | 主訓練           | The "hard" part. Avoid 工作. |
| Recovery         | 恢復             | Between intervals. |
| Cool-down        | 緩和             | Or "收操" (more colloquial). |
| Step Goal        | 步驟目標         | |
| Distance         | 距離             | |
| Time             | 時間             | |
| Open-ended       | 開放式           | "Runs until you tap Lap" style. |
| Step Alert       | 步驟警示         | The pace/HR guidance enforced on Watch. |
| Yours            | 我的             | Workshop segment. |
| Templates        | 範本             | Workshop segment. "模板" is also fine but 範本 reads more product-y. |
| Preset           | 預設訓練         | Built-in template fixtures. |
| Duplicate        | 複製             | |
| Source           | 來源             | |
| Workout Detail   | 訓練詳情         | |
| Workout Editor   | 訓練編輯器       | |
| Start Workout    | 開始訓練         | UI button. But see do-not-translate note about "Start" semantics. |
| Send to Apple Watch | 傳送至 Apple Watch | Disambiguates: not in-app timing. |

### 1.4 App surfaces / tabs

| English          | 正體中文         | Notes |
| ---------------- | ---------------- | ----- |
| Plan (tab)       | 計畫             | Tab title. |
| Workouts (tab)   | 訓練             | The Workshop tab is exposed as "Workouts" — TW: 訓練. |
| Insights (tab)   | 數據分析         | "洞察" is awkward in zh-Hant. |
| Settings (tab)   | 設定             | |
| Full Schedule    | 完整課表         | Inside Plan tab. |
| Fitness trend    | 體能趨勢         | Insights card. |
| Weekly mileage   | 週跑量           | Standard TW term. |
| Predicted race times | 預估比賽成績  | |

### 1.5 UI chrome (verbs / common actions)

| English          | 正體中文         | Notes |
| ---------------- | ---------------- | ----- |
| Save             | 儲存             | |
| Cancel           | 取消             | |
| Delete           | 刪除             | |
| Edit             | 編輯             | |
| Add              | 新增             | |
| Remove           | 移除             | |
| Update           | 更新             | |
| Browse           | 瀏覽             | |
| Dismiss          | 關閉             | |
| Done             | 完成             | |
| Done (saved)     | 已儲存           | Past-tense state confirmation. |
| Failed           | 失敗             | |
| Saving           | 儲存中           | |
| Sent             | 已傳送           | |
| Adjust           | 調整             | "Adjust VDOT" → "調整 VDOT". |
| Recalculate      | 重新計算         | |

### 1.6 Recovery banner / adaptive copy

| English          | 正體中文         | Notes |
| ---------------- | ---------------- | ----- |
| Recovery looks low today | 今天恢復狀況不佳 | Banner title. |
| Swap to Easy     | 改為輕鬆跑       | Action chip. |
| HRV low          | HRV 偏低         | Reason chip. HRV stays English. |
| only X h sleep   | 僅 X 小時睡眠   | Reason chip. |
| VDOT improved    | VDOT 提升        | Upgrade banner. |
| Update paces     | 更新配速         | Upgrade banner CTA. |

### 1.7 Voice / Siri dialog (App Intents)

Spoken phrases are translated for natural Siri speech, not word-for-word.

| English (dialog)                              | 正體中文                                       |
| ---------------------------------------------- | ---------------------------------------------- |
| "Today's session is tempo run, 20 minutes at threshold pace, 4:25 to 4:35 per kilometre." | 「今天的訓練是節奏跑，20 分鐘，乳酸閾值配速 4:25 到 4:35 每公里。」 |
| "Today is a rest day. Stay easy."             | 「今天是休息日，放輕鬆。」                     |
| "Sending Mona Fartlek to your Apple Watch."   | 「正在把 Mona Fartlek 傳送到你的 Apple Watch。」 |
| "Open Workouts on your Watch when ready."     | 「準備好後請在 Apple Watch 打開「體能訓練」。」 |
| "VDOT set to 52."                              | 「VDOT 已設為 52。」                           |
| "Logged a 5 km run in 25 minutes."             | 「已記錄一筆 5 公里、25 分鐘的跑步。」         |

---

## 2. Do-not-translate list

These stay in English in **every** locale, including zh-Hant UI.

### 2.1 Brand & product

- **RunCraft** — the app name.

### 2.2 Scientific acronyms

- **VDOT** — the Daniels-derived fitness number. Never translated; "氧氣攝取量" is *not* equivalent.
- **VO₂max** — physiological term, widely recognised in TW running circles.
- **HRV** — heart rate variability. Pair with "(心率變異)" in body text the first time it appears, then drop.
- **BPM** — beats per minute. Keep.

### 2.3 Daniels pace-zone letters

- **E / M / T / I / R** — the universal Daniels notation. Render alongside the Chinese name in chip labels: `E 輕鬆跑` / `M 馬拉松` / `T 乳酸閾值` / `I 間歇` / `R 反覆衝刺`.

### 2.4 Workout preset names

Named after people stay English; descriptive ones translate.

| Preset                       | zh-Hant strategy                      |
| ---------------------------- | ------------------------------------- |
| **Yasso 800s**               | Keep. Bart Yasso 是專有名詞。可以附「（亞索 800）」first-time hint. |
| **Mona Fartlek**             | Keep. Steve Moneghetti 是專有名詞。  |
| Cruise Intervals 3×1 mile    | 翻成「巡航間歇 3×1 英里」            |
| Ladder 400→1200→400          | 翻成「階梯 400→1200→400」(numbers stay) |
| Tempo Run                    | 翻成「節奏跑」                        |
| Easy Recovery Run            | 翻成「輕鬆恢復跑」                    |

### 2.5 Units

- **km / mi / m / s / min** — keep abbreviations.
- **/km / /mi** — pace suffixes — keep.
- **°C** — keep.
- Numerals stay Arabic (1, 2, 3), never converted to 一二三 in UI.

### 2.6 Apple system / framework terms

Match Apple's own zh-Hant localization where they have one.

| Term              | UI label in zh-Hant            |
| ----------------- | ------------------------------ |
| Apple Watch       | Apple Watch (keep)             |
| Apple Watch's Workouts app | Apple Watch 的「體能訓練」(Apple's own TW name) |
| HealthKit         | Don't expose in UI — use "健康" only when pointing at Apple's Health app. |
| Siri              | Siri (keep)                    |
| Spotlight         | 「聚焦搜尋」(Apple's TW localization) |
| Apple Intelligence| Apple Intelligence (Apple keeps English globally) |
| WorkoutKit        | Internal only. Never in UI.    |
| App Store         | App Store (keep)               |

### 2.7 People / personal nouns

- **Jack Daniels** — keep. The methodology's author. Pair with "教練" on first mention if needed.

---

## 3. Implementation plan

### 3.1 Tech stack

- **String Catalogs (`.xcstrings`)** — Xcode 15+. Auto-extracts strings, supports plurals/devices, replaces the legacy `Localizable.strings` + `Localizable.stringsdict` pair.
- One catalog **per SPM target** that has user-facing strings, plus one in the app target for `AppShortcutsProvider` phrases.
- SwiftUI auto-localizes `Text("…")` because `Text(_ key: LocalizedStringKey)` looks up the calling module's bundle. SPM auto-generates `Bundle.module` for resource-bearing targets.

### 3.2 Targets that need a catalog

| Target                  | What it contributes                                                         |
| ----------------------- | --------------------------------------------------------------------------- |
| `AppFeature`            | Tab titles, Settings copy, About text.                                      |
| `TrainingPlanFeature`   | Plan dashboard, countdown, banners, full schedule, AdjustVDOT.              |
| `WorkshopFeature`       | Workouts tab, editor, edit sheets, presets list, empty states.              |
| `InsightsFeature`       | Card titles, picker labels, chart legends.                                  |
| `DesignSystem`          | None — pure tokens; no user-facing strings live here.                       |
| `RunCraftModels`        | Enum display names (`SessionType.displayName`, `TrainingPhase.displayName`). |
| `VDOTEngine`            | `PaceZoneName.displayName`, `PaceZoneName.letter` (letter stays untranslated). |
| `AppleWatchSync`        | Error messages from `WorkoutKitError`.                                      |
| `HealthKitClient`       | `RaceDistanceQuery.displayName`, typical-range hints.                       |
| `RunCraftIntents`       | Intent titles/descriptions, dialog strings, snippet copy.                   |
| **App target** (`RunCraft/`) | `AppShortcut` voice phrases, `Info.plist` keys.                       |

### 3.3 Package.swift change per localized target

```swift
.target(
    name: "TrainingPlanFeature",
    dependencies: [...],
    resources: [
        .process("Resources/Localizable.xcstrings")
    ]
)
```

After running once, Xcode reads from the catalog automatically; no
`Bundle.module` plumbing needed in view code because SwiftUI
`Text("…")` already resolves against the calling-module bundle.

### 3.4 Migrating existing call sites

Strings to migrate fall into three patterns:

**Pattern A — pure literal `Text`**

```swift
// Before
Text("Save")

// After (no code change — string just needs a row in the catalog)
Text("Save")
```

Xcode 15 auto-scans these and surfaces them in the catalog editor.

**Pattern B — interpolation**

```swift
// Before
Text("Week \(week.weekNumber) · \(week.phase.displayName)")

// After — same code, the catalog row uses `%lld · %@`:
Text("Week \(week.weekNumber) · \(week.phase.displayName)")
```

zh-Hant entry: `"第 %lld 週 · %@"`.

**Pattern C — domain-enum `displayName`**

```swift
// Before
public var displayName: String {
    switch self {
    case .easy: "Easy Run"
    ...
    }
}

// After — return LocalizedStringResource
public var displayName: LocalizedStringResource {
    switch self {
    case .easy: "Easy Run"   // key — translated in caller's bundle
    ...
    }
}
```

Or keep `String` and translate at the call-site with
`String(localized: "Easy Run")` so the string-extraction tool picks it up.

**Pattern D — explicit "don't translate" (brand, units)**

```swift
Text(verbatim: "RunCraft")           // never localized
Text(verbatim: "VDOT")                // never localized
Text(verbatim: "\(km, format: …) km") // numeric literal — but "km" stays
```

`Text(verbatim:)` opts out of `LocalizedStringKey` lookup.

### 3.5 App Intents localization

`LocalizedStringResource` is the canonical type for intent metadata.
Catalog entries live in the **same module as the intent declaration**
(here: `RunCraftIntents`).

```swift
public static let title: LocalizedStringResource = "What's today's training?"
public static let description = IntentDescription(
    "Read the planned RunCraft session for today out loud, with target distance, duration and pace.",
    categoryName: "Training"
)
```

Both the user-facing title/description **and** the spoken `dialog`
need zh-Hant entries.

### 3.6 AppShortcutsProvider phrases

The phrases array carries Siri's voice triggers. Each phrase must have
a per-locale entry — Siri only matches the localized variant.

```swift
AppShortcut(
    intent: WhatIsTodaysTrainingIntent(),
    phrases: [
        "What's today's training in \(.applicationName)",
        // zh-Hant: 「\(.applicationName) 今天的訓練」
        ...
    ],
    shortTitle: "Today's Training",
    systemImageName: "figure.run"
)
```

Translation strategy:

| English phrase                                | 正體中文 phrase                              |
| ---------------------------------------------- | -------------------------------------------- |
| What's today's training in RunCraft           | RunCraft 今天的訓練                          |
| What's today's RunCraft training              | 今天的 RunCraft 訓練                         |
| Start `<workout>` in RunCraft                 | 在 RunCraft 開始 `<workout>`                 |
| Send `<workout>` to my Watch in RunCraft     | 把 `<workout>` 傳送到我的 Apple Watch        |
| Set my VDOT to `<X>` in RunCraft              | 設定 RunCraft 的 VDOT 為 `<X>`               |
| Log a run in RunCraft                          | 在 RunCraft 記錄一筆跑步                     |

### 3.7 Info.plist & project setup

Project-level steps (one-time):

1. **Xcode Project → Info → Localizations** — add `Chinese (Traditional) — zh-Hant`. Use `zh-Hant`, not `zh-TW`, so it matches all Traditional regions (TW + HK + MO).
2. **App target Info.plist** — add `CFBundleLocalizations` array: `["en", "zh-Hant"]`.
3. **Privacy strings (`NSHealthShareUsageDescription`, etc.)** — translate inline in Info.plist via the localization columns Xcode adds.

### 3.8 Plurals & 量詞

zh-Hant has no plural inflection (一天/兩天/五天 share the same form),
so xcstrings plural rules collapse to `.other`. Keep the plural-marker
in English entries to avoid "1 days" — xcstrings will offer per-form
zh-Hant entries that we collapse to one.

| English | zh-Hant |
| ------- | ------- |
| "1 day" / "N days" | "1 天" / "N 天" — same form |
| "1 step" / "N steps" | "1 步驟" / "N 步驟" |

### 3.9 Testing the build

- **Xcode preview**: each `#Preview` block can pin a locale with `.environment(\.locale, Locale(identifier: "zh-Hant"))`.
- **Simulator**: Settings → General → Language & Region → set `繁體中文`.
- **Scheme**: Edit Scheme → Run → Options → App Language → 繁體中文 — overrides without changing the simulator system language.
- **Siri**: requires the device language be zh-Hant for `AppShortcut` voice phrases. Type-mode Siri uses the keyboard language.

### 3.10 Sequencing (implementation order)

1. **Glossary lock-in** — this doc + agreement on debatable picks (e.g. 範本 vs 模板).
2. **Wire up catalogs** — add `.xcstrings` to each target's `Resources/`. No translations yet — get the build green.
3. **Migrate enum `displayName`s** to `LocalizedStringResource` (RunCraftModels, VDOTEngine).
4. **Add zh-Hant entries** module by module, in this order:
   1. `AppFeature` (tab titles, Settings) — most visible
   2. `TrainingPlanFeature` (dashboard)
   3. `WorkshopFeature` (editor)
   4. `InsightsFeature` (charts)
   5. `RunCraftIntents` (Siri)
   6. App target's AppShortcutPhrase
5. **Adjust verbatim opt-outs** — sweep for "RunCraft", "VDOT", unit abbreviations.
6. **Preset name fork** — split named (Yasso, Mona) vs descriptive (Tempo Run → 節奏跑) in `WorkoutPresets`.

### 3.11 Future locales

Once zh-Hant is solid, adding more locales is cheap — Xcode's String
Catalog UI lets you add a column per locale. The expensive part is
this doc (the glossary) and the migration (steps 2–3 above), both of
which are one-time.

Candidate next locales by Daniels'-running audience size: Japanese
(jp), Korean (ko), Simplified Chinese (zh-Hans).

---

## 4. Locked decisions

Five debatable picks were resolved before translation started:

1. **Template → 範本** (vs 模板). 範本 reads more product-y.
2. **Plan → 計畫** (vs 計劃). Both acceptable in TW; this codebase uses 計畫 throughout. Apply globally — including derived terms like 訓練計畫 and the Plan tab title.
3. **Workouts tab → 訓練** (vs 課表 / 訓練庫). Most concise; matches the broader use of 訓練 in the glossary.
4. **Preset names → split**. People-named presets (Yasso 800s, Mona Fartlek) stay English; descriptive ones translate (Tempo Run → 節奏跑, Easy Recovery Run → 輕鬆恢復跑, Cruise Intervals → 巡航間歇, Ladder → 階梯).
5. **Pace chip labels → contextual.** Full label (`E 輕鬆跑`) on first appearance in a screen; letter only (`E`) inside dense chip rows.
