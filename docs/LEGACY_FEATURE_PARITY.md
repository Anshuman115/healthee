# Legacy feature migration

Audited against the read-only `healthee-legacy/app/lib/ui`, its API client and
background services on 2026-09-06. This document distinguishes implemented flows
from physical-device verification. Production deployment is a separate step.

| Legacy capability | Implemented entry point and behavior |
| --- | --- |
| Strap pairing, authenticated BLE, collection and upload | Pairing, pull-to-refresh, Settings and Diagnostics; packet validation, resumable rounds, partial-failure reporting and account-bound upload preserved |
| Today and overnight summaries | Recovery, vitals, sleep, activity, fitness and findings; active challenges and the compact Tonight focus restored |
| Sleep | Stages, vitals, need/debt, regularity, history, naps, tonight guidance and grounded analysis |
| Activity and workouts | Activity → Recorded workouts; session detail with minute HR averages, zones, pace, speed, TRIMP, intensity and grounded workout analysis |
| Metric history | Insights and metric explainers → History; 20 metrics, 30/90/365/1825-day ranges, touch selection, mean/median/range/change, dated values and manual-log markers |
| Profile | Settings → Profile; explicit name, DOB, sex, height, activity self-report and optional new weigh-in; dated BMI uses stored inputs |
| Manual logs and fasting | Actions or Settings → Health journal; caffeine, alcohol, meditation, exercise, weight, habits and fasting start/end, plus recent entries |
| Challenges | Actions → suggested, active and recent challenges; generation, adoption, progress, adaptation and abandonment; Today links active commitments |
| Programs | Actions → programs and their rungs; generation, adoption, abandonment, progress and frozen rung outcomes |
| Outcome review and completion notices | Actions/Insights → Outcomes; adherence, confidence, confounders and observed changes; new server-confirmed completions have an on-screen notice and optional notification |
| Recommendation history | Actions → Action history and adoption; dated 30/90/180-day pages, citations and acknowledged adopt/dismiss state |
| Insights | Existing cited coach and findings plus notable events and lazy metric/activity/workout analysis |
| Outdoor GPS workout | Activity → Record outdoor workout; elapsed time, average pace, distance and fix count; screen-off recording, interrupted-run recovery, durable retryable upload |
| Saved GPS routes | Activity/GPS → Saved routes; map, elevation/HR/pace coloring and profiles, summary, elevation range and session fitness estimate when supported |
| Background controls | Settings → Background sync; separate collection/upload intervals, unmetered-network and charging constraints, explicit enable/disable and last-attempt status |
| Notifications | Settings → Reminders; opt-in daily focus, chosen bedtime/wind-down and challenge completion; local timezone scheduling, cancellation on account change and destination links |
| Appearance | Settings → Appearance; persisted system/light/dark, seven accent choices and espresso/dark/AMOLED backgrounds |

## Data and lifecycle guarantees

- No guessed demographics or prefilled new weigh-ins. Profile edits affect later
  analysis; the UI does not promise an immediate historical recalculation.
- History uses canonical server values. Missing days break the line; zero remains
  zero. The five-year limit is explicit (legacy labelled the same 1825 days “All”).
  Even-count medians use the middle pair. Historical confidence flags are not in
  this endpoint; current metric cards retain their confidence disclosures.
- Challenge, program, outcome, journal and notable-event caches carry timestamps.
  Refresh failures remain visible. Session changes reject old requests/results;
  authentication or access refusals evict the relevant cached feed.
- Recommendation adoption records intent, not completion. Challenge outcomes
  remain observational, with coverage and confounders visible. No new health
  score or AI entry point was introduced.
- Journal forms retain an unconfirmed save while open, then clear only on server
  acknowledgement. They are not a durable offline queue. Because this log API
  lacks idempotency keys, the app does not automatically retry uncertain writes.
- GPS fixes are committed before updating the display. Local routes are bound to
  stable authenticated owner ID plus server origin, survive restart, and upload
  using an immutable client UUID. A lost-response retry does not create another
  workout. At least ten valid fixes are required; accuracy worse than 50 m is
  rejected; each recording is capped at 28,800 fixes. Maps show up to 2,000 points
  with that limitation disclosed; the stored route retains every accepted fix.
- SQLite schema v5 adds GPS tables; v4’s removal of unowned server caches remains
  intact. Pending strap measurements and existing credentials are preserved.
- Foreground and scheduled workers arbitrate strap access and uploads through
  SQLite leases. Disposing a connection stops lease timers. Background failures
  are recorded; a notification failure does not overwrite a successful sync.
- Scheduling and reminders default off. OS scheduling is best effort, not an
  exact interval guarantee. Permission prompts happen from explicit user actions,
  never from a scheduled BLE scan. GPS permission is requested on Start.
- Reminder preferences are bound to a sign-in namespace. Sign-out cancels them;
  signing in again requires opting in again. Old completion history is seeded
  quietly, and failed notification delivery can retry without marking it seen.

## Backend compatibility

Deploy the matching server changes before expecting all new mobile flows to work:

- `GET /api/account`: authenticated stable owner identity for local GPS storage.
- `PATCH /api/profile`: validated partial profile edit and explicit new weigh-in.
- `GET /api/profile`: date-of-birth and BMI fields.
- `GET /api/history`: daily weight and MVPA flag components.
- `GET /api/history/logs`: bounded, owner-local daily log markers.
- `GET /api/recommendations` and recommendation adopt/dismiss writes.
- GPS ingest accepts optional `client_id` and validates ordered coordinates and
  timestamps; retries preserve the first accepted recording.

The recommendation routes use the existing premium gate. Existing challenge,
program, insight, journal and route APIs remain the canonical source. A server
without the new endpoints produces a visible error, not fabricated data.

## Verification

- Backend: **2,359 tests passed**, including seeded TimescaleDB contracts,
  least-privilege tenant access, premium gates, profile editing, GPS retries,
  local-day log markers and unchanged science regression suites.
- Ruff lint/format, Pyright, the 400-line gate and scoped whitespace checks pass.
- Android debug APK: native build passed with the GPS, Workmanager, notification
  and persistent-appearance plugins. Third-party plugins emit Kotlin migration
  and Java compatibility warnings; these do not fail the current build.
- Mobile: **1,232 tests passed**, followed by **12 passing targeted checks**
  after the final compatibility retry/formatting fix; Flutter analyze reports zero issues. GPS
  interruption/retry, account switching, feed fallback/access refusal, scheduler
  constraints, reminder cancellation/retry/deep links, appearance persistence,
  legacy screen semantics and navigation are covered.
- iOS native configuration uses deployment target 14, registered background task
  identifiers, plugin registration and location/Bluetooth modes. An iOS build and
  physical execution cannot be verified on this Linux/Android workstation.

Device smoke check, 2026-09-06: the complete debug APK was installed in place on
Android 16, preserving sign-in and pairing. Today, Actions, workout history,
workout detail (HR chart and zones), metric history and Settings loaded. The
background controls expanded with scheduling still disabled. Observed app logs
had zero fatal/unhandled exceptions or layout-error markers. No fabricated logs,
challenge adoption, GPS route or reminder schedule was submitted.

The measured debug cold launch was 2,405 ms. This is not a release-mode startup
benchmark and does not establish the 2-second performance budget.

A read of the live backend's public OpenAPI schema confirmed that `/api/account`,
`/api/history/logs`, `/api/recommendations` and `PATCH /api/profile` are absent.
These flows therefore cannot pass live acceptance until backend deployment. The
latest installed APK was checked to surface the missing-endpoint error on Today
immediately; transient HTTP failures get at most one provider retry. History remains readable if log markers are unavailable.

Physical acceptance still needs a real outdoor route with screen off, subsequent
strap HR alignment, OS-triggered background runs and actual reminder delivery.
Automated tests do not establish radio reliability, location accuracy, reminder
latency or release-mode performance budgets. No production deployment or invented
health-data writes are part of these checks.

## Beyond legacy

Water, mood and symptom logs are also available through the existing manual-log
API, without invented targets or diagnostic interpretation. Other new health
features are deferred until parity acceptance; they are not claimed as shipped.

Native setup references checked during implementation:
[Workmanager](https://docs.page/fluttercommunity/flutter_workmanager/quickstart),
[local notifications](https://pub.dev/packages/flutter_local_notifications), and
[Google Maven desugaring metadata](https://dl.google.com/dl/android/maven2/com/android/tools/desugar_jdk_libs/maven-metadata.xml).
