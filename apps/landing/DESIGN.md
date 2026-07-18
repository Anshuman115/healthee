# Landing page — design decisions (v5)

The binding design record for `apps/landing`. Any agent extending this page works
**inside** this system — read it in full before writing UI code. Content rules come
first because they outrank everything visual: this page is bound by the same
honesty contract as the product (`docs/PRICING.md` §0/§1a/§2 and the README status
block are the ground truth for every claim).

> **v5 keeps v3's structure, re-dresses the skin, and simplifies the copy.**
> The showcase (a rendered surface per honesty claim) is v3's; the *look* is new
> ("The Ledger", replacing v3's "Instrument"); the *voice* is v4's plain everyday
> English. v1 (warm-paper editorial), v2 (serif field-journal / margin rail),
> v3 (cool-porcelain "Instrument" / iris accent) and v4 (manifesto minimalism)
> are all retired — do not reintroduce their identities.

## 1. Content rules (these outrank the design)

- **Claim only what is built.** README's status block is the source of truth. The
  mobile app is unshipped ⇒ no app-store buttons, no device shots, no "download
  now", no waitlist that posts nowhere. The conversion surfaces are the run-it-
  yourself CTA and the "we run it, opens with the app" card — both honestly
  labelled, agreeing with the status ribbon (sign-ups **closed**).
- **Premium/unbuilt features stay visibly marked** ("Planned, not built yet" — the
  greyed `○` list in the coach card), never present tense.
- **Competitors:** only Whoop and Oura, only their §2-cited prices, always with the
  source links and the "current as of 2026-07" date. Everything else stays
  categorical, never named. **Zepp** (the app the strap ships with) is named
  factually and neutrally — "the app the band comes with shows you the basics" —
  with **no** invented Zepp specifics, no Zepp pricing, no disparagement beyond
  "Healthee shows you more of what the band already knows".
- **Every rendered surface is captioned as an example**, not a live reading.
- **No research name-dropping** (owner, 2026-07). The page does **not** prove
  itself academically: no named methods (Jurca / Banister / TRIMP / Phillips SRI /
  Gompertz / Tanaka / Benjamini–Hochberg), no primary-paper listing, no evidence-
  grade ladder as an academic showcase, no `[note_id]` citation tags in the
  surfaces. The honesty *promise* stays, in v4's plain form ("everything it tells
  you is backed by real research you can read yourself — or it doesn't say it").
  Sources shrinks to just the two competitor pricing links.
- **Security/custody claims are limited to what the repo verifiably does**
  (README self-hosting guide + `docs/MULTI_USER.md` §3.3), stated in plain words:
  per-account isolation, Supabase-owned passwords, internet-closed DB + encrypted
  transit, nightly off-box backups. **No** encryption-at-rest, audit, or
  compliance claims; no "bank-grade" language; the technical terms (RLS / TLS)
  never appear — they're described plainly ("kept separate", "scrambled on the way").
- No composite marketing score, no invented statistics, no testimonials, no user
  counts. When honesty and persuasiveness conflict, honesty wins.

## 2. The concept — "The Ledger"

An honest logbook, not a dashboard. Where v3 floated soft-shadowed rounded cards
on cool porcelain, v5 is **flat and ruled**: crisp 1px hairline frames, near-
squared corners (`--r-card: 6px`), a full-width ledger hairline opening every
section, and **depth built from borders, not shadow**. The persuasive core is
unchanged — rendered surfaces that show what no competitor can: the product
**refusing to score**, **refusing to answer**, and reading **your** data first.
Here those surfaces read as sheets torn from a careful logbook.

What this rules out: gradients-as-decoration, glassmorphism, decorative animation,
stock imagery, emoji, serif identity, and the "green ring" language of reward-
driven trackers. The one atmospheric texture — a faint graph-paper grid behind the
hero (`.grid-atmos`, masked to fade out) — is structural (measured/ruled), not a
colour wash.

## 3. Colour system

All colour flows through CSS custom properties in `src/styles/global.css`
(`:root` = light, `.dark` = dark), mapped into Tailwind v4 via `@theme`. **Use the
semantic token utilities (`bg-canvas`, `text-ink-soft`, `border-line`,
`text-accent-soft`, `text-warn`…), never raw hex in components.** **Light is the
DEFAULT** (owner decision): the pre-paint seed applies dark only when the visitor
chose it via the toggle — the OS preference is not followed. Both themes stay fully
designed. **Brand colours (`accent*`, `warn*`) are the SAME hex in both themes**;
only the neutrals (canvas/card/ink/line/shadows) re-pick for dark.

| Token | Role | Light | Dark |
|---|---|---|---|
| `canvas` | page background | `#f4f2ed` | `#16130e` |
| `card` | rendered surfaces | `#fbfaf6` | `#201c16` |
| `sunk` | recessed bands / tool-trace | `#ebe8e0` | `#100d09` |
| `ink` / `ink-soft` / `ink-faint` | text hierarchy | `#201c15` / `#5b544a` / `#8a8274` | `#f2efe7` / `#b1a99a` / `#7b7264` |
| `line` / `line-strong` | hairlines / frames | `#e0dccf` / `#cbc5b4` | `#2f2a22` / `#423b30` |
| `accent` / `accent-soft` | THE one accent — a clay/terracotta | `#bd4a2a` / `#c2542f` | same as light |
| `warn` | honesty flags ("not enough data", "won't answer") | `#4d6488` | same as light |

Decisions:
- **One accent, a clay/terracotta** — warm, editorial, deliberately NOT green-ring
  green and a full hue away from v3's iris. It marks actions, links, the product's
  own data line, and the sparkline; never "success".
- **Warn is a cool slate, reserved for honesty moments** — the insufficient-data
  chip, the "won't answer" verdict, the strike-through on a refused draft, the
  "from your data" personal-finding tag. A held breath, not an alarm; a feature
  colour, not an error colour. (Internal token name stays `warn`.)
- **Depth is border + rule, not shadow.** Surfaces carry a 1px frame and a barely
  there shadow; primary examples get a 2px clay top-rule (`.surface-key`). Both
  modes are first-class — check every change in both.

## 4. Typography — two roles, all system fonts

No webfonts (self-containment is a hard constraint). No serif. Meaning is carried by
**role, weight and precision**:

- **Sans** (`ui-sans-serif`/`system-ui` stack) — everything. Headings are weight
  **700** (heavier than v3's 600) with tight display tracking
  (`letter-spacing: -0.022em`, `line-height ~1.08`, `text-wrap: balance`); prose is
  `line-height 1.62`. The premium feel comes from weight contrast and ruled spacing.
- **Mono** (`ui-monospace` stack) — every data value, unit, price, chip, label and
  caption, with `tabular-nums` (`.mono`). Mono-for-data is what makes the surfaces
  read as a logbook. Never set a metric or price in the prose face.
- `.display-line` — the one place a *spoken* sentence is set large (the coach's
  voice, the refusals): sans, weight 640, tight.
- `.eyebrow` is the functional ledger label (a short clay tick, then mono uppercase
  in `ink-faint`) — an **in-content label only, never a marketing kicker above a
  heading**. Section H2s go straight in, unadorned.

Scale: fluid via `clamp()` — hero `clamp(2.5rem,6.2vw,4.6rem)`, section headings
`clamp(1.9rem,4vw,3rem)`. `.lede` is the large intro paragraph (sans, ink-soft).

## 5. Component vocabulary

Global (`global.css @layer components`): `.shell` (page column, `max-width 72rem`),
`.section` (rhythm + top ledger hairline), `.band-sunk`, `.eyebrow`, `.lede`,
`.mono`, `.display-line`, `.surface` (+ `.surface-lift`, `.surface-key`), `.chip`
(squared stamps; + `.chip-dot`, `.chip-accent`, `.chip-warn`), `.btn-primary` /
`.btn-ghost` (the only two buttons; one primary action per view), `.hairline`,
`.link-underline`, `.grid-atmos` (hero graph-paper texture).

Surface vocabulary (`surfaces.css`, each dresses a *rendered example*): `.turn*`
(coach transcript), `.toolcall` (the visible `query_metric` lookup — the mechanism
no competitor prints), `.check*` + `.flow*` (the two hard checks + the plain
sequence), `.grade-row` (the plain confidence ladder — no grade names), `.anno-*`
(metric-card annotation stamps), `.blocked` / `.verdict` (the refused-answer demo),
`.srclist` / `.srcitem` (Sources), `.cov` (the honest coverage cells), `.spark`
(inline SVG sparkline — clay line over a clay-tint band). **No** citation-token
(`.cite`) or code-window classes: citations are cut and there is no code block.

`Section.astro` is the wrapper: `id`, optional `tone` (`canvas` | `sunk`),
`labelledby`. Rhythm + optional recessed band only — no margin rail, no §-numbering.

## 6. Copy voice — v4's plain everyday English

The reader owns a fitness band; they are not an engineer. Read every headline,
lede, label and chip aloud — if a smart friend with a band would ask "what does
that mean?", rewrite it. **v4's actual sentences are the voice reference** (the
refusal card, the "Did I sleep okay?" exchange, the strap paragraph, the free-vs-
paid framing, the data promises, the goodbye) — reuse them where they fit.

**Banned in all copy** (headlines, ledes, labels, chips, and now the surfaces too):
`pipeline`, `validator`, `manifest`, `RLS`, `TLS`, `FDR`, `RMSSD`, `Benjamini`,
and any named research method (`Jurca` / `Banister` / `TRIMP` / `Phillips` /
`Gompertz` / `Tanaka`). Grep the built HTML for that list after any copy change —
there must be **zero** hits anywhere. Translations in use: the checks pipeline →
**"Why it can't lie to you"**; the refusal demo → **"Some answers it won't give"**;
grade calibration → **"The more certain the science, the more plainly it speaks"**;
the personal stats → **"tested hard enough to rule out coincidence"**; the security
mechanism → **"kept separate from everyone else's"**.

## 7. Motion policy

Motion only clarifies; nothing loops or decorates.
- One pattern: `.rise` — 16px translate + fade on first viewport entry
  (IntersectionObserver, unobserved after firing — **reveal-once**).
- **Triple-gated:** hidden-then-revealed ONLY when JS ran AND
  `prefers-reduced-motion` is off (the `<head>` script adds `.js-anim`; CSS scopes
  all hiding under `.js-anim .rise`). No JS or reduced-motion ⇒ everything visible.
- Micro-motion: 0.18s colour/border transitions and a 1px `:active` press on
  buttons (also reduced-motion-gated).

## 8. Theming mechanics

- Manual theming via a `.dark` class on `<html>` (Tailwind v4 `@custom-variant
  dark`), seeded **pre-paint** by the inline head script: `localStorage` only —
  **DARK is the default (owner decision 2026-07-17); light only when the visitor
  chose it via the toggle; the OS preference is not followed**. No flash.
- The nav toggle writes `localStorage` and flips the class; `aria-pressed` reflects
  state; `meta name="color-scheme" content="light dark"` is set.
- New components style both modes through the tokens — raw hex breaks dark mode.

## 9. Hard technical constraints

- **Self-contained:** zero external fonts, scripts, CDNs, trackers, or remote
  images. The favicon is an inline SVG data-URI (the clay mark). A small Vite
  plugin in `astro.config.mjs` strips Tailwind's `/*! …tailwindcss.com */` legal
  banner from the emitted CSS, so the only `http(s)://` in `dist/` are the two
  cited competitor sources and the `w3.org/2000/svg` namespace.
- **No horizontal scroll at any width:** `overflow-x: hidden` on body; wide content
  (the tool-trace) isolated in its own `overflow-x: auto` container.
- **Accessibility:** semantic landmarks, skip link, `:focus-visible` rings,
  `aria-label`/`figure` on rendered examples, `role="img"` + label on the
  sparkline, contrast checked in both modes.
- **`compressHTML: false` must stay** (`astro.config.mjs`): compression strips
  whitespace-only text nodes at inline boundaries and glues words together.
- Stack: Astro (static) + Tailwind v4 via `@tailwindcss/vite`. Every file ≤ 400
  lines. Verify with `npm run build`, then grep `dist/` for external refs and the
  banned list after any change.

## 10. File map

```
src/layouts/Base.astro     head, theme/motion seeding, skip link, reveal observer
src/styles/global.css      tokens + core component classes (the design system)
src/styles/surfaces.css    the rendered-surface vocabulary (imported into global)
src/components/Section.astro   the section wrapper (band + ruled rhythm)
src/pages/index.astro      section order
src/components/            one section per file — the FULL v5 stack:
  Nav · Hero (refusal card + coverage cells + status ribbon) · Differentiators ·
  CoachExchange (the visible query_metric lookup + "Did I sleep okay?") ·
  Pipeline ("Why it can't lie" — the two hard checks) ·
  GuardrailDemo ("Some answers it won't give") ·
  GradeScale ("The more certain the science, the more plainly it speaks") ·
  MetricAnatomy (annotated card + sparkline) ·
  ScienceLayer ("what the band's own app doesn't show" — the Zepp reframe) ·
  PersonalScience (the caffeine finding) · Pricing (tiers + sourced comparison) ·
  SelfHost (two ways to run it + the data-custody promise) ·
  Disclaimer (the honest goodbye) · Sources (two competitor links) · Footer
```
