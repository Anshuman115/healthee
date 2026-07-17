# Landing page — design decisions (v2)

The binding design record for `apps/landing`. Any agent extending this page (new
sections, a blog, docs pages) works **inside** this system — read this in full
before writing UI code. Content rules come first because they outrank everything
visual: this page is bound by the same honesty contract as the product
(`docs/LANDING_PAGE_PROMPT.md` is the original brief; `docs/PRICING.md` §0/§1a/§2
is the ground truth for pricing/positioning; `docs/INTELLIGENCE.md` §1/§3/§4 is
the ground truth for how the AI layer actually works).

## 1. Content rules (these outrank the design)

- **Claim only what is built.** README's status block is the source of truth.
  The mobile app is unshipped (Phase 2) ⇒ no app-store buttons, no device
  screenshots, no "download now", no waitlist form that posts nowhere. The
  conversion surface is the self-host CTA plus the honest status ribbon.
- **Premium/unbuilt features stay visibly marked** ("Planned, not yet built" —
  greyed `○` list inside the premium card), never present tense.
- **Competitors:** only Whoop and Oura, only their §2-cited prices, always with
  the "current as of 2026-07" date and a footnote to the vendor's own page.
  Everything else is categorical ("subscription trackers"), never named.
- **Every rendered product surface is captioned as an example**, not a live
  reading. Demo numbers are illustrative and say so.
- **Product-mechanism claims must be true per `docs/INTELLIGENCE.md`.** In
  particular: do **not** say the coach is "routed through one choke point" — it
  is *enforced-equivalent* (§4). The page says every surface is held to the same
  blocking checks, and the pipeline note states the coach re-runs them itself.
- **Citations are real or absent.** Named scientific methods footnote their
  primary source; product-mechanism claims footnote the engineering record
  (`INTELLIGENCE.md`); rendered `[note_id]`s use real corpus ids. Citations are
  kept at a verifiable granularity (author · title · venue · year), not
  fabricated volume/page numbers.
- No composite marketing score, no invented statistics, no testimonials, no user
  counts. No social proof exists, so the page ships without social proof.
- When honesty and persuasiveness conflict, honesty wins — and the tension gets
  flagged in review, not resolved in the copy's favour.

## 2. The concept — "The Grounded Record"

The page reads like a **rubricated scientific field-journal**: bone paper and
iron-gall ink, hairline rules, a §-numbered margin rail, and footnote citations
that resolve to a real reference apparatus at the foot of the page. The footnotes
are a design feature, not an afterthought — fitting for a product whose entire
thesis is "every claim is cited". Rigor is the luxury; restraint is the law.

The persuasive core is the **built AI layer shown as product surfaces**: a real
coach exchange that makes a visible tool call and cites its claims; the
grounded-ask pipeline drawn as an annotated diagram; a perfectly-cited answer
being *blocked* by the output guardrail ("cited is not enough"); the five-grade
language scale; and one annotated metric card. No competitor can print these.

What this rules out: gradients, glassmorphism, decorative animation, stock
imagery, emoji, and the "green ring" visual language of reward-driven trackers.
The one concession to translucency is the sticky nav (paper at 85% + blur) as a
legibility aid, not decoration.

## 3. Color system — rubrication (red-lead + gold on bone)

All color flows through CSS custom properties in `src/styles/global.css`
(`:root` = light, `.dark` = dark), mapped into Tailwind v4 via `@theme` — **use
the semantic token utilities (`bg-paper`, `text-ink-soft`, `border-line`,
`text-accent`…), never raw hex in components.**

| Token | Role | Light | Dark |
|---|---|---|---|
| `paper` | page background | `#f2eee3` | `#16130d` |
| `raised` | cards/surfaces | `#faf7ef` | `#201b13` |
| `sunk` | recessed bands (alternating sections) | `#e9e3d3` | `#100d08` |
| `ink` / `ink-soft` / `ink-faint` | text hierarchy | `#211d16` / `#574f42` / `#8a8271` | `#ece4d4` / `#b1a891` / `#7c7461` |
| `line` / `line-strong` | hairlines / interactive borders | `#ddd5c4` / `#c9bea8` | `#322c21` / `#463d2d` |
| `accent` / `accent-soft` | red-lead — THE accent (marks, links, buttons) | `#ac3521` / `#c1402a` | `#df6a4d` / `#ea7f63` |
| `gold` | rubric gold — honesty flags ONLY | `#93641b` | `#d6a445` |

Decisions behind it:
- **One accent, a red-lead vermilion** — the editor's correction mark. It marks
  citations, evidence, actions, and section numbers; it never means "success".
  A hard departure from v1's instrument-teal, and truer to a product that
  *corrects* you.
- **`--c-accent` is the text/citation color; `--c-accent-soft` is for hover,
  borders, and tints.** The token flips per theme (dark red in light, bright red
  in dark), so small colored text stays AA-legible in both modes by using
  `accent`, while `accent-soft` carries interactive/hover states.
- **Gold is rubric, reserved strictly for honesty moments** ("not enough data",
  an FDR-validated personal finding). It is a feature color, not an error color —
  the refusal is the product working.
- Dark mode is a **full re-pick** (deep reading-room brown-black, brightened
  ink), not an inversion. Both modes are first-class; check every change in both.

## 4. Typography — three roles, all system fonts

No webfonts (self-containment is a hard constraint). Meaning is carried by
**role**, and the serif does more editorial work than in v1:

- **Serif** (`ui-serif`/Georgia/"Iowan Old Style" stack) — display (`h1–h3`),
  the `.lede` intro paragraphs, and the "spoken" lines inside product surfaces
  (the user's question, the refusal). Weight 500, `-0.012em`, tight leading,
  `text-wrap: balance`.
- **Sans** (system-ui stack) — all running prose, list items, UI. `line-height 1.62`.
- **Mono** (`ui-monospace` stack) — **every number, price, label, chip, citation,
  footnote marker, eyebrow, and caption**, with `tabular-nums` (`.mono`). This is
  the load-bearing rule: mono-for-data is what makes the page read as an
  instrument. Never set a metric, price, id, or source in the prose face.

Scale is deliberately **high-contrast**: hero `clamp(2.6rem,6.4vw,4.9rem)`,
section headings `clamp(1.9rem,4vw,2.9rem)`, `.eyebrow` at 0.72rem / 0.24em
tracking / uppercase, footnote markers (`.ref`) tiny superscript mono.

## 5. Component vocabulary

Core classes live in `global.css @layer components`; the specialised
product-surface vocabulary lives in `src/styles/surfaces.css` (imported into the
same Tailwind entry so tokens + cascade layers resolve, and to keep both style
files under the 400-line cap). Reuse these; don't invent parallel ones.

- `Section.astro` — **the signature layout device.** A `.rail` grid renders a
  §-numbered gutter (sticky on ≥62rem, stacked below) carrying a mono margin
  `note`, plus a body slot. Every numbered section composes through it.
- `.shell` — the page column: `max-width 78rem`, fluid `clamp` padding.
- `.surface` — a rendered product card: `raised` bg, 1px `line` border, 12px
  radius, soft `--shadow-card`. Product surfaces are the ONLY elevated elements.
- `.lede` — the serif intro paragraph under a section heading.
- `.ref` + the `References.astro` apparatus — the footnote motif. Superscript
  `.ref` markers link to `#ref-N`; the reference list defines matching anchors
  (`:target` highlights). Keep the marker↔anchor set 1:1.
- `.chip` (+ `.chip-dot`, `.chip-accent`, `.chip-gold`) — mono pill for status,
  confidence, evidence labels. `.chip-gold` is honesty-only.
- Surface vocabulary (`surfaces.css`): `.turn`/`.turn-user`/`.turn-coach` +
  `.cite`/`.cite-personal` (coach transcript), `.toolcall` (the visible tool
  call), `.pipe`/`.pipe-step`/`.pipe-block` (annotated pipeline; `.pipe-block`
  marks a blocking stage), `.grade-row` (language scale), `.anno-mark`/
  `.anno-legend` (metric-card anatomy), `.blocked`/`.verdict` (the guardrail
  demo), `.code-win`/`.code-bar` (self-host snippet), `.reflist`/`.refitem`.
- `.btn-primary` (accent fill) / `.btn-ghost` (hairline) — the only two buttons.
  One primary action per view. `.eyebrow`, `.hairline`, `.link-underline`, `.mono`.
- Section rhythm: `.section` = `clamp(4rem,9vw,7rem)` block padding; bands
  alternate `paper` / `band-sunk` (a background swap, hairline-bordered),
  eyebrow → serif heading → `.lede` → content.

## 6. Motion policy

Motion only clarifies; nothing loops, nothing decorates.

- One pattern: `.rise` — 14px translate + fade on first viewport entry,
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
  images. The favicon is an inline SVG data-URI (the annotated-record mark).
  Justify every `http(s)://` in `dist/` — currently only: the two cited
  competitor sources (`whoop.com`, `ouraring.com`), the `127.0.0.1` healthz
  example in the self-host snippet, the SVG namespace, and Tailwind's license
  comment. **None are loaded.**
- Responsive with **no horizontal scroll at any width**: `overflow-x: hidden` on
  body; wide content (the code block, the tool-call chip) is isolated in its own
  `overflow-x: auto` container.
- Accessibility: semantic landmarks, skip link, `:focus-visible` rings,
  `aria-label`/`figure` on rendered examples, `aria-labelledby` on sections,
  contrast checked in both modes (small colored text uses `--c-accent`).
- Stack: Astro (static output) + Tailwind v4 via `@tailwindcss/vite` (no
  `@astrojs/tailwind`). Every file stays under the repo's 400-line cap.
- Verify with `ASTRO_TELEMETRY_DISABLED=1 npm run build` + `npm run preview`;
  grep `dist/` for external references after any change.

## 9. File map

```
src/layouts/Base.astro     head, theme/motion seeding, skip link, reveal observer
src/styles/global.css      tokens + base + core component classes (the system)
src/styles/surfaces.css    specialised product-surface + annotated-diagram classes
src/pages/index.astro      section order
src/components/
  Section.astro            the §-numbered margin-rail shell (reused by all sections)
  Nav.astro                sticky nav + theme toggle
  Hero.astro               masthead + the refusal "record entry" + status ribbon
  Differentiators.astro    §01 — the three differentiators
  CoachExchange.astro      §02 — a rendered coach reply with a visible tool call
  Pipeline.astro           §03 — the grounded-ask pipeline, annotated (blocking stages)
  GuardrailDemo.astro      §04 — "cited is not enough": a cited answer, blocked
  GradeScale.astro         §05 — the five evidence grades + enforced tone
  MetricAnatomy.astro      §06 — one annotated metric card
  ScienceLayer.astro       §07 — named methods, footnoted + vitals
  PersonalScience.astro    §08 — FDR-controlled findings + the caffeine cutoff
  Pricing.astro            §09 — tiers (free-led) + the sourced competitor note
  SelfHost.astro           §10 — the code-block CTA
  Disclaimer.astro         brand-voice limits
  References.astro         the footnote apparatus (marker ↔ anchor payoff)
  Footer.astro             footer
```
