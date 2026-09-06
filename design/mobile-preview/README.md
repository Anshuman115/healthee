# Healthee mobile design preview · v02

A standalone, interactive HTML proposal for the mobile redesign. Production
Flutter, server and landing-page code are unchanged. This is a design to review
before implementing the new interface in Flutter.

## Open it

With Node.js 22.12+ (or 20.19+), from the repository root:

```sh
cd design/mobile-preview
npm ci
npm run dev
```

Open **http://localhost:8765** on desktop. Vite listens on all network interfaces;
open its printed Network URL on a phone connected to the same Wi-Fi/LAN. No
mobile-app installation is needed. `index.html` also works directly from the
filesystem; scripts, fonts and sample data are bundled locally.

For a dependency-free static alternative, run
`python -m http.server 8765 --bind 0.0.0.0 --directory design/mobile-preview`
from the repository root.

## v02: complete data, connected views

The current direction uses a dark health dashboard with category colours and
restored chart depth. See [CHART_COVERAGE.md](CHART_COVERAGE.md) for the inventory
against the current Flutter app. Green identifies recovery/fitness, violet sleep,
coral heart/load, amber movement/energy and blue breathing/oxygen.

Sleep keeps its four explicit checks: duration, efficiency, regularity (SRI) and
timing. Each shows the reading, reference, result and what is outside the range.
The 25-entry metric explorer includes all 20 historical metrics from the app.

## Explore

- **Today:** recovery → contributing signals → tonight's focus; sleep, movement,
  heart-rate trace, journal and coach entry points.
- **Sleep:** stage timeline, four independent dimensions, overnight vitals,
  estimated need and debt, consistency, history and naps.
- **Activity:** steps through the day, active minutes, workouts, heart-rate zones,
  fitness, training load, saved GPS routes and a recording flow.
- **Insights:** personal observations, metric histories, research context,
  fitness and biological-age explanations.
- **Actions:** intentions, challenges, target adjustment, program steps, outcome
  reviews, action history and journal.
- **Supporting flows:** coach, profile, appearance, reminders, background sync,
  device pairing, data freshness, account/server setup and welcome.

The **Explore** control opens a screen directory and sample-day states: normal,
missing data, offline and illness signal. Desktop also has a persistent directory.
Appearance includes light, dark and system modes. Charts accept touch and arrow
keys. Browser back works, and each screen has a shareable hash route.

Suggested review path: Today → Recovery details → Sleep → Actions → Journal →
Insights → Activity → Workout → Settings → Appearance. Use Explore to compare
the missing-data and offline designs.

## Design decisions

- Keep Manrope and restore per-metric colour identity from the current app.
  The user's v02 direction supersedes the older single-indigo brief.
- A primary reading has its immediate context nearby. Detailed methods and
  limitations open on demand instead of dominating the everyday view.
- Custom SVG line/area charts, stage plots, activity bars, signal comparisons,
  progress views, sleep timing and route/elevation plots share one visual system.
- Native mobile proportions with no imitation phone bezel or status bar.
- Light and dark tokens are authored separately in OKLCH. Main text token pairs
  exceed 4.5:1 contrast in both themes; focus and chart accents remain distinct.
- Motion is limited to short opacity/transform transitions. Reduced motion uses
  a 100 ms fade; focus indicators appear immediately.

## Sample data and functional limits

Measurements in `sample-data.js` are copied from versioned July contract fixtures,
with local research-note excerpts. The screens are a curated visual composition,
not a replay of a live API response. The illness flag is a selectable review
scenario. Dates and sample labels deliberately do not claim current readings.

Some fixtures are intentionally repetitive or internally inconsistent. The
prototype preserves their chart values rather than inventing richer trends:

- Stage timelines and summary totals can disagree; the sleep screen identifies
  that limitation. The displayed four sleep dimensions compare sample readings
  with the reference cutoffs, without copying inconsistent fixture pass flags.
- No scatter plot is fabricated from a correlation summary with no paired data.
- No historical confidence band is invented when only a baseline is supplied.
- Longer history controls retain the actual sample date range and explain the
  missing server-backed window. These controls demonstrate the unavailable state.
- The route uses sample coordinates on a labelled schematic, not real map tiles.
- The biological-age waterfall shows the actual reconciled calculation:
  36 − 1.7 fitness + 0.0 sleep = 34.3. Excluded regularity is separate.

Journal entries, preferences, profile changes, intentions and target changes
live only in the current tab's memory and reset on reload. Pairing, sign-in,
sync and coach replies are explicitly simulated. The recording timer collects
no GPS. This preview requests no device permissions, stores no credentials,
uses no analytics and performs no backend requests. Research links open only
when deliberately selected.

This is screen and interaction coverage for design review, not production feature
parity or a new analysis implementation. Production permission prompts, seven
accent variants and long-range data will reuse their
existing implementations when the design is approved.

## Verification

`tests/preview.cjs` uses an available Playwright installation and Chromium:

```sh
PLAYWRIGHT_MODULE=/path/to/playwright-core \
CHROMIUM_PATH=/path/to/chromium \
node design/mobile-preview/tests/preview.cjs
```

The browser acceptance pass covers every screen and all 25 metric routes at
320, 375, 414 and 768 px in light mode, plus 375 px in dark mode. It checks overflow, unresolved
links/actions, browser errors, chart keyboard interaction, journal input escaping,
intent adoption, target adjustment, coach citations, reminder toggles, pairing,
sync, the recording timer, reduced motion and absence of external requests.
Screenshots and the result JSON go to `/tmp/healthee-design-review` by default.

Review the visual direction before changing Flutter. Prototype state and sample
data must not be ported as production business logic.
