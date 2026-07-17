# Landing page — design decisions (v4)

The binding design record for `apps/landing`. Any agent extending this page works
**inside** this system — read it in full before writing UI code. Content rules come
first because they outrank everything visual: this page is bound by the same honesty
contract as the product. `docs/PRICING.md` §0/§1a/§2 is the ground truth for every
money claim; `README.md`'s status block is the ground truth for what's built.

> **v4 is a clean-slate rebuild. It supersedes v1, v2 and v3 completely.**
> v1 (editorial), v2 ("The Grounded Record" — serif field-journal with a margin
> rail and footnote citations) and v3 ("The Instrument" — cool graphite/porcelain,
> mono-for-data, chips, tight tracking) all shared ONE skeleton: a split hero with a
> product card, then a stack of proof sections (differentiators grid → coach
> transcript → pipeline → grade scale → metric card), then pricing columns →
> self-host → disclaimer → sources. **That skeleton is forbidden.** So are all of
> its motifs: the mono-for-data face, the chips, the `[note_id]` tags, the tool-call
> traces, the code/terminal blocks, the grade ladder, the §-numbered margin rail,
> the serif identity. None of them return.

## 1. Content rules (these outrank the design)

- **Radically plain language — the first law.** Every sentence must be understandable
  by a five-year-old and an eighty-year-old. No jargon, anywhere, including inside the
  rendered examples. **Banned everywhere on the page:** pipeline, validator, manifest,
  RLS, TLS, FDR, RMSSD, VO₂max, HRV, SpO₂, tool-call JSON, `[note_id]` tags, code
  blocks, terminal snippets, "encryption", "compliance", Supabase/Postgres/Docker/API.
  Technical truth is expressed as a **plain promise**: "kept separate", "your password
  never touches us", "backed by real research you can read". If a sentence needs a
  second read, rewrite it. Grep the built HTML for the banned list after any change.
- **The anchor is fixed:** *"the health companion that refuses to flatter you."* The
  whole page is one story about flattery vs. truth — other apps cheer; this one tells
  the truth, kindly.
- **We do not sell hardware.** Healthee is a *companion app* for the Amazfit Helio
  Strap — "a small, screenless band you can buy on your own, from anyone." Say plainly
  that we don't sell it and aren't part of the company that makes it. **Never** imply
  we bundle, sell, or are affiliated with the strap.
- **Work in progress, honestly.** The backend runs today; the app is being built;
  sign-ups are **not** open. So: no sign-up form, no waitlist, no app-store buttons,
  no device mockups. The GitHub link is **not public yet** — the page says "the code
  goes up on GitHub the moment it's ready to run yourself; the link will appear right
  here." No clone commands, no fake links.
- **Pricing, simply** (`PRICING.md` §0/§1a): everything the band records is free
  forever; the AI coach is the paid part — **$3.99/mo, $34.99/yr, $99 once**
  (early-supporter, "while it lasts"). One sourced context line is allowed: Whoop
  $199+/yr, Oura $69.99/yr + $349 ring — both dated **July 2026** with links to their
  own sites. Unbuilt things (challenges/programs, coach memory) are simply omitted.
- **The data promise, in plain words only:** kept separate from everyone else's · your
  password never touches us · backed up every night · never sold · no trackers on this
  page. Claim **nothing** beyond that — no encryption/compliance/audit/"bank-grade"
  badges.
- **Every rendered surface is captioned as an example** ("An example of what it
  says"), never a live reading. No invented statistics, testimonials, or user counts.
  "Not enough to be sure" beats a guess. A plain-voice limits line is mandatory (not a
  medical device, won't diagnose, will tell you to see a doctor).
- When honesty and persuasiveness conflict, **honesty wins.**

### Claims → sources
| Claim on the page | Source |
|---|---|
| $3.99/mo · $34.99/yr · $99 once; free tracking, paid coach | `docs/PRICING.md` §0, §1a |
| Whoop from $199/yr | https://www.whoop.com/us/en/membership/ (PRICING §2, dated 2026-07) |
| Oura $69.99/yr + $349 ring | https://ouraring.com/membership (PRICING §2, dated 2026-07) |
| "kept separate from everyone else's" | README (row-level tenancy), in plain words |
| "your password never touches us" | README (Supabase-owned auth), in plain words |
| "backed up every night" | README self-hosting guide (nightly off-box backup) |
| companion for the Helio Strap; backend runs, app being built, sign-ups closed | README status block |

### Deliberately left out (would over-claim or repeat the forbidden skeleton)
The differentiators grid, the coach tool-trace, the "why it can't lie" two-check
pipeline, the guardrail-refusal demo, the evidence-grade ladder, the annotated metric
card + sparkline, the named-methods science layer, the personal-correlations card, the
self-host code block + `/healthz` snippet, the sourced comparison table, encryption /
compliance badges, and any per-user export button (not built). Also: no OS-preference
theme following, no eyebrow/kicker lines, no green.

## 2. The concept — "The Honest Voice"

A **single-column story told in the product's own voice** — closer to a beautifully
typeset letter or a spoken conversation than a SaaS page. **Typography is the design:**
enormous confident type, one warm accent, a lot of air. The only elevated elements are
two *quiet cards* where the app speaks plainly. There are **no** feature grids, tables,
diagrams, columns, numbered how-it-works stacks, or data chrome of any kind. The
persuasion is the voice itself — the app saying the honest thing where every other app
would flatter.

## 3. The structural spine — SIX moments, in the product's voice

One flowing column (`.wrap`, `max-width 46rem`). Each moment is a `<section>` with its
own headline; the story carries the reader, not a nav of sections. **Max six moments —
adding a seventh, or any grid/table/column, means you've rebuilt the forbidden
skeleton.**

1. **The opening truth + the turn + the anchor** — *"Every app tells you 'great job.'
   Even when it isn't true."* Then the turn: Healthee is the one that won't; it refuses
   to flatter you.
2. **One quiet moment of honesty** — *"Most days it has plenty to say. Some days it says
   this."* → the first quiet card: *"I don't have enough to score you today. Wear it
   tonight and I'll know more in the morning."* (captioned as an example).
3. **What it is** — *"A companion for a band you can buy anywhere."* The Helio Strap (we
   don't sell it), free numbers / paid coach, the coach shown as **one warm plain
   exchange** (second quiet card), then pricing in plain prose with the Whoop/Oura
   context line.
4. **How you'll get it + the data promise** — *"When it's ready, there'll be two honest
   ways to get it."* We run it for you (opens with the app) · run it yourself (code goes
   up on GitHub, link appears here). Then "Your numbers stay yours." as plain promises.
5. **The honest goodbye** — *"It won't pretend to be your doctor."* The limits line +
   "still being built … watch this space."
6. *(Footer)* — a quiet close: what it is, and the not-a-medical-device line. No
   newsletter, social row, or badges.

## 4. Colour system

All colour flows through CSS custom properties in `src/styles/global.css` (`:root` =
light, `.dark` = dark), mapped into Tailwind v4 via `@theme`. **Use the semantic token
utilities (`bg-canvas`, `text-ink-soft`, `border-line`, `text-ink-faint`…) or
`var(--c-*)` inline — never raw hex in components.** Light is the default identity; the
warm accent is **identical hex in both themes** (only the neutrals re-pick).

| Token | Role | Light | Dark |
|---|---|---|---|
| `canvas` | page background | `#f7f4ef` (warm paper) | `#191510` (warm near-black) |
| `raised` | the quiet cards | `#fffdf9` | `#221d16` |
| `ink` / `ink-soft` / `ink-faint` | text hierarchy | `#211d18` / `#5c554c` / `#938b7f` | `#f3ede2` / `#b3a996` / `#837868` |
| `line` / `line-strong` | hairlines / borders | `#e6ded2` / `#d6ccbc` | `#302a20` / `#40382c` |
| `accent` / `accent-ink` | THE one accent (warm clay) — **same hex both themes** | `#bf4d2b` / `#fff8f3` | `#bf4d2b` / `#fff8f3` |

Decisions:
- **One accent, a warm clay/rust `#bf4d2b`** — deliberately NOT green (never a reward
  ring), and a clean break from v3's cool iris/indigo. It marks one emphasised word per
  headline, the buttons, and link underlines — **never small body text** (clay-on-canvas
  is ~4.1:1, below AA for small text, so links carry `ink` with an accent underline; the
  accent only ever appears at display size, where 3:1 is met in both themes, or as a
  button fill where white-on-clay is ~4.9:1).
- **No amber "honesty" colour, no second hue.** The honesty *is* the words; it doesn't
  need a feature colour. This is another intentional break from v3.
- **Depth is a whisper.** The quiet cards carry one soft shadow (`--shadow-quiet`) and,
  on dark only, a 1px inset top highlight (`--edge-top`). Nothing else is elevated.

## 5. Typography — one system-sans voice, no mono

Self-containment forbids webfonts, so everything is the `system-ui` sans stack. The
break from v3 is deliberate: **there is no mono face anywhere** (mono-for-data was v3's
signature; dropping it kills the "instrument" look and serves the plain-language law).
No serif either (that was v2). Meaning is carried by **scale and weight**, not novelty:

- `.say-huge` — the opening truth: weight 700, `clamp(2.85rem, 7.6vw, 6rem)`, tracking
  `-0.028em`, line-height 1.02.
- `.say-big` — every moment headline: weight 700, `clamp(1.95rem, 4.6vw, 3.4rem)`.
- `.warm` — the single accent-coloured word inside a headline (display size only).
- `.lede` — the relaxed reading voice: `clamp(1.15rem, 1.7vw, 1.4rem)`, `ink-soft`.
- `.plain` — body prose, `ink-soft`.
- `.voice` — **what Healthee says**, inside a quiet card: weight 500,
  `clamp(1.3rem, 2.6vw, 1.85rem)`, `ink`. This is the closest thing to a signature.
- `.aside` — the small "this is an example" note above/below a card: `0.82rem`,
  `ink-faint`. Human, never a chip.

No eyebrow/kicker line exists — headings stand on their own.

## 6. Component vocabulary

Global (`global.css @layer components`): `.wrap` (the 46rem reading column),
`.moment` / `.moment-tight` (vertical rhythm), `.say-huge`, `.say-big`, `.warm`,
`.lede`, `.plain`, `.quiet` (the card), `.voice`, `.aside`, `.btn` + `.btn-primary` /
`.btn-ghost` (the only two buttons), `.u-link` (ink text + accent underline), `.rule` /
`.rule-soft`. There is intentionally **no** surfaces vocabulary file — v3's
`surfaces.css` (chips, tool-traces, grade rows, verdicts, code windows, sparklines) was
deleted; those motifs are forbidden.

## 7. Motion policy

Motion only clarifies; nothing loops or decorates.
- One pattern: `.rise` — 16px translate + fade on first viewport entry
  (IntersectionObserver, unobserved after firing — reveal-once).
- **Triple-gated:** elements hide-then-reveal ONLY when JS ran AND
  `prefers-reduced-motion` is off (the `<head>` script adds `.js-anim`; CSS scopes all
  hiding under `.js-anim .rise`). No JS or reduced-motion ⇒ everything renders fully
  visible. A 1px `:active` press on buttons is the only micro-motion (also
  reduced-motion-gated).

## 8. Theming mechanics

- **Light is the default. Dark is opt-in only — we do NOT follow the OS preference.**
  The pre-paint head script adds `.dark` *only* when `localStorage('healthee-theme')`
  is exactly `'dark'`; there is no `prefers-color-scheme` fallback (a deliberate change
  from v3). No flash either way.
- The nav toggle writes `localStorage` and flips the `.dark` class; `aria-pressed` and
  `aria-label` reflect state; the sun/moon icon shows the theme you'd switch *to*.
- New components style both modes through the tokens — use the semantic utilities or
  `var(--c-*)` and dark mode is free; raw hex breaks it.

## 9. Hard technical constraints

- **Self-contained:** zero external fonts, scripts, CDNs, trackers, or remote images.
  The favicon is an inline SVG data-URI. The build (`npm run build`) runs
  `scripts/strip-css-banner.mjs` after Astro to remove Tailwind's `/*! … */` license
  banner, so the **only** `http(s)://` strings left in `dist/` are the two cited
  competitor links and the SVG namespace (`w3.org/2000/svg`). Verify with:
  `grep -rhoE "https?://[^\"' )]+" dist/ | sort -u`.
- **No horizontal scroll at any width:** `overflow-x: hidden` on body; the single
  narrow column and word-wrapped prose never overflow.
- **Accessibility:** semantic landmarks, skip link, `:focus-visible` rings,
  `figure`/`aria-label` on the two rendered examples, contrast checked in both modes
  (see §4).
- **`compressHTML: false` must stay** (`astro.config.mjs`): compression strips
  whitespace-only text nodes at inline boundaries and glues words to inline `<span>`s.
- Stack: Astro (static) + Tailwind v4 via `@tailwindcss/vite`. Every file ≤ 400 lines
  (repo cap). After any change: `npm run build`, grep `dist/` for external refs and the
  banned-jargon list, and confirm both themes render.

## 10. File map

```
src/layouts/Base.astro     head, light-default theme seed, motion flag, skip link, reveal observer
src/styles/global.css      tokens + the whole (small) component vocabulary — the design system
src/components/Nav.astro    wordmark + theme toggle (no CTA — sign-ups are closed)
src/components/Footer.astro the quiet close
src/pages/index.astro       the six-moment story (the whole page lives here, in order)
src/pages/404.astro         the same honest voice ("we won't pretend it does")
scripts/strip-css-banner.mjs  post-build: strip the CSS license banner so dist/ stays clean
```
