# TODOs — Open Questions and Future Work

> Things that are deliberately not done yet, with the reasoning behind
> the deferral. When a new "we should do X eventually, but not now"
> idea comes up, add a row here rather than letting it live only in
> conversation — this file is git-tracked and survives session resets.

| What                                  | Why it isn't done                                                                |
| ------------------------------------- | -------------------------------------------------------------------------------- |
| **iCloud sync via `SyncEngine`**      | SQLiteData supports CloudKit sync; we haven't enabled it. Single device only today. Main benefit: device-migration/backup protection — today, losing/replacing the iPhone or deleting the app loses months of training history and VDOT progression with no recovery path. CloudKit's *private* database stays tied to the user's own iCloud account (consistent with the "no servers" privacy stance — see `docs/privacy.md`, which already frames this as a planned v2.0 addition). Not urgent pre-launch; revisit once v1.0 users start accumulating data worth protecting. |
| **App-level theme override**          | The user's system Appearance setting wins. A future Settings toggle (Auto / Light / Dark) could let runners pin a mode regardless of system. |
| **App icon — Liquid Glass redesign** | Current icon (commit `68653da`, 85% progress ring + `figure.run`) ships as flat light/dark/tinted PNGs (`RunCraft/Assets.xcassets/AppIcon.appiconset`). iOS 26 native apps use the layered "Liquid Glass" icon format (specular highlights, depth, translucency via Icon Composer's multi-layer `.icon` format). Explore re-authoring the existing progress-ring + figure.run concept as a layered icon for that look — not done yet, needs Icon Composer (Xcode 26) exploration + design pass. |
| **Widget doesn't follow the in-app pace-unit setting** | `PaceUnit.current` (`VDOTEngine/PaceFormatting.swift`) reads `UserDefaults.standard`, which isn't shared across the App Group — `TodayWidget` always sees `.perKilometre` regardless of the runner's setting in Settings → Units. Fixing this means moving the `paceUnit` preference into `UserDefaults(suiteName: "group.io.marstudio.RunCraft")`, which touches every `@Shared(.n("paceUnit"))` call site (`PlanView`, `WeekScheduleView`, `WorkshopView`, `InsightsView`, etc.). Out of scope for the widget's first version. |
