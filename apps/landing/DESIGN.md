# Landing page — design decisions (v3)

The binding design record for `apps/landing`. Any agent extending this page works
**inside** this system — read it in full before writing UI code. Content rules come
first because they outrank everything visual: this page is bound by the same
honesty contract as the product (`docs/LANDING_PAGE_PROMPT.md` is the original
brief; `docs/PRICING.md` §0/§1a/§2 is the ground truth for every claim).

> **v3 supersedes v2.** v2 ("The Grounded Record") was a rubricated scientific
> field-journal: serif display, a §-numbered margin rail, footnote citations, warm
> paper-and-ink. That editorial identity is **retired**. v3 is a premium consumer
> product page. Do not reintroduce the serif face, the margin rail, or the
> superscript-footnote motif.

## 1. Content rules (these outrank the design)

- **Claim only what is built.** README's status block is the source of truth. The
  mobile app is unshipped (Phase 2) ⇒ no app-store buttons, no device screenshots,
  no "download now", no waitlist that posts nowhere. The conversion surfaces are the
  self-host CTA and the "hosted, opens with the app" card — both honestly labelled,
  agreeing with the status ribbon (sign-ups **closed**).
- **Premium/unbuilt features stay visibly marked** ("Planned, not yet built" — the
  greyed `○` list in the premium card), never present tense.
- **Competitors:** only Whoop and Oura, only their §2-cited prices, always with the
  source links and the "current as of" date. Everything else is categorical
  ("subscription trackers"), never named.
- **Every rendered product surface is captioned as an example**, not a live reading.
- **Citations are real.** Every `[note_id]` shown on the page resolves to a real note
  in `packages/knowledge` (`recovery_readiness`, `biological_age_estimate`,
  `exercise_mortality`, `no_validated_sleep_score`). The corpus today holds only
  **Established** and **Probable** grades — so the grade ladder attaches a real id
  only to those two rungs and says so; it never fabricates a note for Emerging /
  Contested / Myth.
- **Security/custody claims are limited to what the repo verifiably does**
  (README self-hosting guide + `docs/MULTI_USER.md` §3.3): row-level isolation +
  least-privilege role, Supabase-owned passwords, internet-closed DB + TLS, nightly
  off-box backups. **No** encryption-at-rest, audit, or compliance (SOC2/HIPAA/GDPR)
  claims; no "bank-grade" language. Per-user export is **not built** — "own your
  data / no lock-in" is framed as the standing commitment (true today for self-host,
  where you hold the whole database), never as a shipped hosted export button.
- No composite marketing score, no invented statistics, no testimonials, no user
  counts. When honesty and persuasiveness conflict, honesty wins.

## 2. The concept — "The Instrument"

A premium consumer product page in the spirit of flagship consumer-hardware and
premium-software sites: **vast negative space, precision typography, and the
product UI as the hero.** The luxury is material and precision — 1px strokes,
layered soft shadows, true depth hierarchy, monochrome sophistication with ONE
refined accent — not decoration. The persuasive core is unchanged from v2: rendered
surfaces that show the thing no competitor can show — the product **refusing to
answer**, **holding back**, and **naming its method**. Here those surfaces read as
screens of a beautiful health app (graphite or porcelain cards), not phone mockups.

What this rules out: gradients-as-decoration, glassmorphism, decorative animation,
stock imagery, emoji, serif identity, and the "green ring" language of reward-driven
trackers.

## 3. Colour system

All colour flows through CSS custom properties in `src/styles/global.css`
(`:root` = light, `.dark` = dark), mapped into Tailwind v4 via `@theme`. **Use the
semantic token utilities (`bg-canvas`, `text-ink-soft`, `border-line`,
`text-accent-soft`, `text-warn`…), never raw hex in components.** **Light is the
DEFAULT** (owner decision 2026-07-17): the pre-paint seed applies dark only when
the visitor chose it via the toggle — the OS preference is not followed. Both
themes stay fully designed. **Brand colours (`accent*`, `warn*`) are the SAME hex
in both themes**; only the neutrals (canvas/card/ink/line/shadows) re-pick for dark.

| Token | Role | Light | Dark |
|---|---|---|---|
| `canvas` | page background | `#fbfcfd` | `#0c0e12` |
| `card` | rendered surfaces | `#ffffff` | `#16191f` |
| `sunk` | recessed bands / code / tool-trace | `#f2f4f8` | `#090b0e` |
| `ink` / `ink-soft` / `ink-faint` | text hierarchy | `#0e1116` / `#545c69` / `#838b98` | `#f1f3f7` / `#a6afbc` / `#6c7580` |
| `line` / `line-strong` | hairlines / interactive borders | `#e6e9ef` / `#d3d9e2` | `#242932` / `#333a45` |
| `accent` / `accent-soft` | THE one accent — an iris/indigo | `#4b45d6` / `#6f6af0` | same as light |
| `warn` | honesty flags ("not enough data", "refused") | `#b0801f` | same as light |

Decisions:
- **One accent, an iris/indigo** — deliberately NOT green-ring green, not the warm
  teal of v2. It marks actions, links, evidence, and the product's own data line;
  never "success".
- **Warn is amber, reserved for honesty moments** — the insufficient-data chip, the
  refusal verdict, the strike-through on a blocked answer, the "from your data"
  personal-finding tag. It is a feature colour, not an error colour.
- **Depth is material, not colour.** Surfaces carry a layered soft shadow
  (`--shadow-card` / `--shadow-lift`) and, on dark only, a 1px inset top highlight
  (`--edge-top`) that reads as brushed graphite. Both modes are first-class — check
  every change in both.

## 4. Typography — two roles, all system fonts

No webfonts (self-containment is a hard constraint). No serif. Meaning is carried by
**role and precision**, not novelty:

- **Sans** (`system-ui` stack) — everything. Headings are weight 600 with **tight
  display tracking** (`letter-spacing: -0.025em`, `line-height ~1.06`,
  `text-wrap: balance`); prose is `line-height 1.6`. The premium feel comes from
  precision (tracking, weight contrast, spacing), the way flagship product pages get
  it from system/near-system faces.
- **Mono** (`ui-monospace` stack) — **every data value, unit, price, chip, label,
  citation, and caption**, with `tabular-nums` (`.mono`). This is load-bearing:
  mono-for-data is what makes the surfaces read as instruments. Never set a metric,
  price, or `[note_id]` in the prose face.
- `.display-line` — the one place a *spoken* sentence is set large (the coach's
  voice, the refusals): sans, weight 560, tight tracking. It replaces v2's serif
  "spoken" lines.

Scale: fluid via `clamp()` — hero `clamp(2.5rem,6.2vw,4.6rem)`, section headings
`clamp(1.9rem,4vw,3rem)`. `.eyebrow` is the mono section label
(0.72rem / 0.2em tracking / uppercase / accent-soft). `.lede` is the large intro
paragraph (sans, ink-soft).

## 5. Component vocabulary

Global (`global.css @layer components`): `.shell` (page column, `max-width 74rem`),
`.section` (rhythm, `padding-block: clamp(4.5rem,10vw,8rem)`), `.band-sunk`,
`.eyebrow`, `.lede`, `.mono`, `.display-line`, `.surface` (+ `.surface-lift`),
`.chip` (+ `.chip-dot`, `.chip-accent`, `.chip-warn`), `.btn-primary` / `.btn-ghost`
(the only two buttons; one primary action per view), `.hairline`, `.link-underline`.

Surface vocabulary (`surfaces.css`, each dresses a *rendered example*): `.turn*` +
`.cite` / `.cite-personal` (coach transcript), `.toolcall` (the visible data
lookup), `.check*` (the two hard checks) + `.flow*` (the plain sequence),
`.grade-row` + `.grade-none` (the wording-vs-evidence ladder), `.anno-*` (metric-card
annotation pins), `.blocked` / `.verdict` (the refused-but-cited demo), `.code-win`
(terminal), `.srclist` / `.srcitem` (Sources), `.cov` (the honest coverage strip),
`.spark` (inline SVG sparkline). Reuse these; don't invent parallel ones.

`Section.astro` is the premium wrapper: `id`, optional `tone` (`canvas` | `sunk`),
`labelledby`. It supplies rhythm + optional recessed band, nothing else — **no
margin rail, no §-numbering.** Each section provides its own eyebrow → heading →
lede.

## 6. Copy voice — human, around "refuses to flatter you"

The reader owns a fitness band; they are not an engineer. Read every headline,
lede, label, and chip aloud — if a smart friend with a band would ask "what does
that mean?", rewrite it. Technical precision LIVES in two places only: **the rendered
surfaces** (the `[note_id]` citations, the `query_metric` lookup, `RMSSD` inside the
card, the stats names inside the finding card) and **the Sources section**.

**Banned in headlines / ledes / labels / chips** (allowed only inside a rendered
surface or Sources): `pipeline`, `validator`, `manifest`, `choke point`,
`grounded-ask`, `pre-classifier`, `enforced-equivalent`, bare `blocking`, and
unexplained `RMSSD` / `FDR` / `Benjamini–Hochberg`. Translations in use:
the pipeline → **"Why it can't lie to you"** (two hard checks: *is this an answer a
health app should ever give?* · *can every claim be backed?*); the guardrail demo →
**"Even a well-sourced answer can be refused"**; grade calibration → **"The wording
matches the strength of the science"**; FDR → **"tested strictly enough to rule out
coincidence"**; the security mechanism → **"isolated by the database itself"** (the
name "row-level security" appears once, in small print).

Grep the built HTML for the banned list after any copy change; every hit must sit
inside a `figure`/surface or the Sources block.

## 7. Motion policy

Motion only clarifies; nothing loops or decorates.
- One pattern: `.rise` — 18px translate + fade on first viewport entry
  (IntersectionObserver, unobserved after firing — **reveal-once**).
- **Triple-gated:** elements are hidden-then-revealed ONLY when JS ran AND
  `prefers-reduced-motion` is off (the `<head>` script adds `.js-anim`; CSS scopes
  all hiding under `.js-anim .rise`). No JS or reduced-motion ⇒ everything renders
  fully visible. Never add an animation that breaks this.
- Micro-motion: 0.18s colour/border transitions and a 1px `:active` press on buttons
  (also reduced-motion-gated).

## 8. Theming mechanics

- Manual dark mode via a `.dark` class on `<html>` (Tailwind v4 `@custom-variant
  dark`), seeded **pre-paint** by the inline head script:
  `localStorage('healthee-theme')` wins, else `prefers-color-scheme`. No flash.
- The nav toggle writes `localStorage` and flips the class; `aria-pressed` reflects
  state; `meta name="color-scheme" content="light dark"` is set.
- New components style both modes through the tokens — if you used the semantic
  utilities, dark mode is free; raw hex breaks it.

## 9. Hard technical constraints

- **Self-contained:** zero external fonts, scripts, CDNs, trackers, or remote images.
  The favicon is an inline SVG data-URI. Justify every `http(s)://` in `dist/`
  (currently: the two cited competitor sources, the healthz example in the self-host
  snippet, and the SVG namespace).
- **No horizontal scroll at any width:** `overflow-x: hidden` on body; wide content
  (the code block, the tool-trace) isolated in its own `overflow-x: auto` container.
- **Accessibility:** semantic landmarks, skip link, `:focus-visible` rings,
  `aria-label`/`figure` on rendered examples, `role="img"` + label on the sparkline,
  contrast checked in both modes.
- **`compressHTML: false` must stay** (`astro.config.mjs`): compression strips
  whitespace-only text nodes at inline boundaries and glues words to `<span>`
  citations.
- Stack: Astro (static) + Tailwind v4 via `@tailwindcss/vite`. Every file ≤ 400
  lines (the repo cap). Verify with `npm run build` + grep `dist/` for external refs
  and the banned-jargon list after any change.

## 10. File map

```
src/layouts/Base.astro     head, theme/motion seeding, skip link, reveal observer
src/styles/global.css      tokens + core component classes (the design system)
src/styles/surfaces.css    the rendered-surface vocabulary (imported into global)
src/components/Section.astro   the premium section wrapper (band + rhythm)
src/pages/index.astro      section order
src/components/            one section per file:
  Nav · Hero (refusal card + coverage strip + status ribbon) · Differentiators
  (the emotional arc) · CoachExchange (tool-trace + citations) ·
  Pipeline ("Why it can't lie" — the two hard checks) ·
  GuardrailDemo ("Even a well-sourced answer can be refused") ·
  GradeScale ("The wording matches the strength of the science") ·
  MetricAnatomy (annotated card + sparkline) · ScienceLayer (named methods) ·
  PersonalScience (your patterns) · Pricing (tiers + sourced comparison) ·
  SelfHost (two ways to run it + the data-custody promise) ·
  Disclaimer (brand-voice limits) · Sources · Footer
```
