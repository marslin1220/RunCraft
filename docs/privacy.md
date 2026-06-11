---
layout: default
title: RunCraft Privacy Policy
permalink: /privacy/
---

# RunCraft Privacy Policy

**Effective date:** 11 June 2026
**Last updated:** 11 June 2026

This Privacy Policy describes how the RunCraft app ("RunCraft", "we", "us")
handles your data. The short version: **your data never leaves your iPhone**.
There are no servers, no accounts, no analytics, and no third-party tracking.

---

## Who we are

RunCraft is an iOS app for serious runners following Jack Daniels' VDOT
training methodology. It is published by Cheng Lung Lin as a personal
project.

- **Contact:** [marslin@gmail.com](mailto:marslin@gmail.com)
- **Source code:** [github.com/marslin1220/RunCraft](https://github.com/marslin1220/RunCraft)

---

## What data RunCraft reads

When you grant permission, RunCraft reads the following from **Apple Health
(HealthKit)** on your iPhone:

- **Running workouts** — distance, duration, start time. Used to detect a
  best 5K / 10K / Half Marathon time and derive your initial VDOT.
- **Heart Rate Variability (HRV)** — last 7 days' average. Used by the
  "Recovery looks low today" banner to suggest swapping a hard session
  for an easy run.
- **Sleep** — last night's total. Same purpose as HRV.
- **VO₂max** — last 180 days of samples. Plotted on the Insights tab
  alongside your VDOT trend.

Reads only. RunCraft **does not write** anything back to HealthKit.

You can revoke this access at any time: **iOS Settings → Privacy &
Security → Health → RunCraft**. When access is revoked, the affected
features (VDOT detection, recovery banner, VO₂max chart) silently stop
working but RunCraft continues to function for everything else.

---

## What data RunCraft stores

Everything RunCraft generates is stored **locally on your iPhone** in a
private SQLite database inside the app's sandbox:

- Your race goal (name, date, distance)
- The generated 16-week training plan
- Workouts you author and templates you save
- Completed run records (when you log them by voice or HealthKit syncs)
- VDOT history (one row per change)
- Your preferences (pace unit, reminder time, etc.)

This database **never leaves your iPhone**. RunCraft has no servers and
performs no network requests for app data.

To delete the data: delete RunCraft from your iPhone.

---

## What Apple frameworks handle

Some features hand off to Apple's own systems, which have their own
privacy policies that apply when they receive data:

- **WorkoutKit** — when you tap "Start Workout", the workout structure
  is dispatched to your paired Apple Watch via Apple's
  `WorkoutScheduler`. Subject to [Apple's privacy policy](https://www.apple.com/legal/privacy/).
- **App Intents / Siri** — when you ask Siri "what's today's training?",
  the response is generated locally but the voice transcription and
  invocation are handled by Apple. Subject to [Apple's Siri privacy
  policy](https://www.apple.com/legal/privacy/data/en/siri/).
- **Local Notifications** — daily training reminders are scheduled via
  `UNUserNotificationCenter` and delivered locally. No notification
  data leaves your iPhone.

RunCraft never sees your Siri transcriptions or your Apple ID.

---

## What we don't collect

To be explicit:

- ❌ No account, no sign-up, no email collection
- ❌ No analytics (no Firebase, no Mixpanel, no Amplitude)
- ❌ No crash reporting service (no Sentry, no Crashlytics)
- ❌ No advertising SDKs
- ❌ No third-party trackers
- ❌ No location data beyond what HealthKit workouts already contain
- ❌ No cloud sync (planned for v2.0; will use Apple's iCloud and remain
  end-to-end private)

---

## Children

RunCraft is rated **4+** on the App Store and contains no objectionable
content. We do not knowingly collect data from children under 13 because
**we do not collect any user-identifying data, period**.

---

## Changes to this policy

If we change how RunCraft handles your data — including any future
addition of iCloud sync, a Pro subscription tier, or analytics — this
page will be updated and the effective date at the top will change.
Material changes will be surfaced in-app via the Settings → About
section so you don't have to re-read the policy to know something has
changed.

---

## Contact

Questions, concerns, or requests: [marslin@gmail.com](mailto:marslin@gmail.com).

---

*Last reviewed: 11 June 2026*
