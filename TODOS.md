# TODOs — Open Questions and Future Work

> Things that are deliberately not done yet, with the reasoning behind
> the deferral. When a new "we should do X eventually, but not now"
> idea comes up, add a row here rather than letting it live only in
> conversation — this file is git-tracked and survives session resets.

| What                                  | Why it isn't done                                                                |
| ------------------------------------- | -------------------------------------------------------------------------------- |
| **iCloud sync via `SyncEngine`**      | SQLiteData supports CloudKit sync; we haven't enabled it. Single device only today. Main benefit: device-migration/backup protection — today, losing/replacing the iPhone or deleting the app loses months of training history and VDOT progression with no recovery path. CloudKit's *private* database stays tied to the user's own iCloud account (consistent with the "no servers" privacy stance — see `docs/privacy.md`, which already frames this as a planned v2.0 addition). Not urgent pre-launch; revisit once v1.0 users start accumulating data worth protecting. |
| **App icon — Liquid Glass redesign** | Current icon (commit `026e3ad`, iconikai runner-with-speed-lines + cyan arc on cyan background, scaled 1.32× so the arc bleeds to the mask edge) ships as flat light/dark/tinted PNGs (`RunCraft/Assets.xcassets/AppIcon.appiconset`, same design for `RunCraftWatch Watch App`). iOS 26 native apps use the layered "Liquid Glass" icon format (specular highlights, depth, translucency via Icon Composer's multi-layer `.icon` format). Explore re-authoring the existing runner + arc concept as a layered icon for that look — not done yet, needs Icon Composer (Xcode 26) exploration + design pass. |
| **Faster Watch data acquisition** [P2] | GPS and HR data takes 2-3 min to appear on Watch vs native Workout.app. Potential improvements: (1) call `CLLocationManager.requestLocation()` immediately in `WatchAppDelegate.handle(_:)` to prime GPS before `startActivity`; (2) configure `HKLiveWorkoutDataSource` to collect `runningSpeed` explicitly; (3) call `builder.add([workoutEvent])` with a `.lapMarker` to nudge the builder. Needs on-device profiling — simulator can't reproduce this. |
