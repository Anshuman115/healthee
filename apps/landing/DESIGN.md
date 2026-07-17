# Landing page — design decisions

The binding design record for `apps/landing`. Any agent extending this page (new
sections, a blog, docs pages) works **inside** this system — read this in full
before writing UI code. Content rules come first because they outrank everything
visual: this page is bound by the same honesty contract as the product
(`docs/LANDING_PAGE_PROMPT.md` is the original brief; `docs/PRICING.md` §0/§1a/§2
is the ground truth for every claim).

## 1. Content rules (these outrank the design)

- **Claim only what is built.** README's status block is the source of truth.
  The mobile app is unshipped (Phase 2) ⇒ no app-store buttons, no device
  screenshots, no "download now", no waitlist form that posts nowhere. The
  conversion surface is the self-host CTA plus the honest status ribbon.
- **Premium/unbuilt features stay visibly marked** ("Planned, not yet built" —
  greyed `○` list inside the premium card), never present tense.
- **Competitors:** only Whoop and Oura, only their §2-cited prices, always with
  the source links and the "current as of" date. Everything else is categorical
  ("subscription-gated trackers"), never named.
- **Every rendered product surface is captioned as an example**, not a live
  reading. Demo numbers are illustrative and say so.
- No composite marketing score, no invented statistics, no testimonials, no user
  counts. No social proof exists, so the page ships without social proof.
- When honesty and persuasiveness conflict, honesty wins — and the tension gets
  flagged in review, not resolved in the copy's favour.

## 2. The concept — "the honest instrument"

The page reads like a well-made lab instrument, not a lifestyle brand: warm
paper and ink, hairline rules, dense-but-calm typography, and product surfaces
that show the thing no competitor can show — **the product refusing to answer**.
The hero's centerpiece is a recovery card declining to produce a score on thin
data. Rigor is the luxury; restraint is the aesthetic.

What this rules out: gradients, glassmorphism, decorative animation, stock
imagery, emoji, and the "green ring" visual language of reward-driven trackers.

## 3. Color system

All color flows through CSS custom properties in `src/styles/global.css`
(`:root` = light, `.dark` = dark), mapped into Tailwind v4 via `@theme` — **use
the semantic token utilities (`bg-paper`, `text-ink-soft`, `border-line`,
`text-accent-soft`…), never raw hex in components.**

| Token | Role | Light | Dark |
|---|---|---|---|
| `paper` | page background | `#f6f4ee` | `#17160f` |
| `raised` | cards/surfaces | `#fcfbf7` | `#1f1d16` |
| `sunk` | recessed bands (code, disclaimer) | `#efece3` | `#131209` |
| `ink` / `ink-soft` / `ink-faint` | text hierarchy | `#1b1a16` / `#565148` / `#857f72` | `#ece7db` / `#ada694` / `#7c7565` |
| `line` / `line-strong` | hairlines / interactive borders | `#e4dfd3` / `#d3ccbc` | `#322f25` / `#443f32` |
| `accent` / `accent-soft` | THE one accent (buttons, chips, links) | `#1c534e` / `#2a736b` | `#62b4a8` / `#82c6bb` |
| `warn` | honesty flags ("not enough data") | `#8a5a1f` | `#d4a25a` |

Decisions behind it:
- **One accent, and it's a dark instrument teal** — deliberately NOT green-ring
  green, not medical blue, not fitness orange. It marks actions and evidence,
  never "success".
- **Warn is an amber reserved for honesty moments** (insufficient-data chips).
  It is a feature color, not an error color — the refusal is the product working.
- Dark mode is a **full re-pick** (desaturated paper, brightened accent for
  contrast), not an inversion. Both modes are first-class; check every change in
  both.

## 4. Typography — three roles, all system fonts

No webfonts (self-containment is a hard constraint). Meaning is carried by
**role**, not by novelty:

- **Serif** (`ui-serif`/Georgia stack) — display only: `h1–h3` and the "spoken"
  lines inside product surfaces. Weight 500, `letter-spacing -0.01em`,
  `line-height 1.08`, `text-wrap: balance`.
- **Sans** (system-ui stack) — all prose. `line-height 1.6`.
- **Mono** (`ui-monospace` stack) — **every number, price, label, chip, citation
  and caption**, with `tabular-nums` (`.mono`). This is the load-bearing rule:
  mono-for-data is what makes the page read as an instrument. Never set a
  metric, price, or source in the prose face.

Scale: fluid via `clamp()` (hero `clamp(2.5rem,6vw,4.25rem)`, section headings
`clamp(1.9rem,4vw,2.9rem)`); `.eyebrow` is the mono section label
(0.72rem / 0.22em tracking / uppercase).

## 5. Component vocabulary (in `global.css @layer components`)

Reuse these; don't invent parallel ones:

- `.shell` — the page column: `max-width 76rem`, fluid `clamp` padding.
- `.surface` — a rendered product card: `raised` bg, 1px `line` border, 14px
  radius, the soft two-layer `--shadow-card`. Product surfaces are the ONLY
  elevated elements on the page.
- `.chip` (+ `.chip-dot`, `.chip-accent`, `.chip-warn`) — mono pill for status,
  confidence, and evidence labels.
- `.btn-primary` (accent fill) / `.btn-ghost` (hairline) — the only two button
  styles. One primary action per view.
- `.eyebrow`, `.hairline`, `.link-underline` (accent underline, offset 3px),
  `.mono`.
- Section rhythm: `py-20 md:py-28`, one `.shell`, eyebrow → serif heading →
  lede → content. Borders between bands are 1px `line`, not background swaps
  (except the `sunk` disclaimer/code bands).

## 6. Motion policy

Motion only clarifies; nothing loops, nothing decorates.

- One pattern: `.rise` — 16px translate + fade on first viewport entry,
  IntersectionObserver, unobserved after firing (**reveal-once**, the same rule
  as the app's chart screens).
- Triple-gated: elements are hidden-then-revealed ONLY when JS ran AND
  `prefers-reduced-motion` is off (the `<head>` script adds `.js-anim`; CSS
  scopes all hiding under `.js-anim .rise`). No JS or reduced-motion ⇒
  everything renders fully visible. Never add an animation that breaks this.
- Micro-motion: 0.18s color/border transitions and a 1px `:active` press on
  buttons (also reduced-motion-gated).

## 7. Theming mechanics

- Manual dark mode via a `.dark` class on `<html>` (Tailwind v4
  `@custom-variant dark`), seeded **pre-paint** by an inline head script:
  `localStorage('healthee-theme')` wins, else `prefers-color-scheme`. No flash.
- The nav toggle writes `localStorage` and flips the class; `aria-pressed`
  reflects state; `meta name="color-scheme" content="light dark"` is set.
- New components must style both modes through the tokens — if you used the
  semantic utilities, dark mode is free; raw hex breaks it.

## 8. Hard technical constraints

- **Self-contained**: zero external fonts, scripts, CDNs, trackers, or remote
  images. The favicon is an inline SVG data-URI. Justify every `http(s)://` in
  `dist/` (currently: the two cited competitor sources, the healthz example in
  the self-host snippet, Tailwind's license comment, the SVG namespace).
- Responsive with **no horizontal scroll at any width**: `overflow-x hidden` on
  body, wide content (the code block) isolated in its own `overflow-x auto`
  container.
- Accessibility: semantic landmarks, skip link, `:focus-visible` rings,
  `aria-label`/`figure` on rendered examples, contrast checked in both modes.
- Stack: Astro (static output) + Tailwind v4 via `@tailwindcss/vite` (no
  `@astrojs/tailwind`). Files stay under the repo's 400-line cap.
- Verify with `npm run build` + `npm run preview`; grep `dist/` for external
  references after any change.

## 9. File map

```
src/layouts/Base.astro    head, theme/motion seeding, skip link, reveal observer
src/styles/global.css     ALL tokens + component classes (the design system)
src/pages/index.astro     section order
src/components/           one section per file:
  Nav · Hero (refusal card + status ribbon) · Differentiators ·
  HonestyShowcase (3 rendered surfaces) · ScienceLayer (methods table) ·
  PersonalScience (FDR/cutoffs) · Pricing (tiers + sourced comparison) ·
  SelfHost (code block CTA) · Disclaimer (brand-voice limits) · Footer
```
