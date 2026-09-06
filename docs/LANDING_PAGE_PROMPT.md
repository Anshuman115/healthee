# Landing page brief (agent-driven)

A reusable brief for building Healthee's public landing page. It exists because the
landing page is the **one artifact where the product's promise and the product's
marketing are the same claim** — "it never flatters" is both the tagline and the
spec. A page that overstates doesn't just mislead; it falsifies the thesis.

**Ground truth lives in `docs/PRICING.md` §1, §1a, §2.** Do not re-derive positioning.

---

## The prompt

````markdown
Build Healthee's public landing page: an **Astro app with Tailwind**, light mode
primary, dark mode secondary. Premium, modern, restrained.

**Live at `apps/web/`** in this monorepo (`apps/server` and `apps/mobile` are its
siblings). Per `CLAUDE.md`, look up the **current** versions of Astro, Tailwind and
anything else you add at write time — never install from memory.

## Read IN FULL before writing a word (do not skim, do not work from summary)
- `README.md` — what the product actually is and its **current status**
- `docs/PRICING.md` — §1 (what's built), §1a (the AUTHORITATIVE tier split),
  §2 (the competitive landscape, with cited prices)
- `CLAUDE.md` — the hard rules; the honesty ethos is not decoration

## The thesis this page must land
Every health app grades you on a curve and sells the green ring. Healthee tells you
the truth — every interpretive claim cited to graded research, every number carrying
its data confidence, and "not enough data" instead of a confident guess. You own the
hardware and the data; you pay only for the intelligence, if you want it.

The design job is to make **rigor feel premium** rather than academic. The honesty
IS the luxury. Restraint, not exuberance.

## ⛔ Honesty constraints — these are hard, and they outrank the copy
This is the product that promises it never lies. The landing page is bound by the
same contract as the coach.

1. **Claim only what is built.** `README.md` states the current status; `PRICING.md`
   §1 lists shipped capability. The **Flutter app is NOT shipped** (Phase 2 is next).
   So: **no App Store / Play Store buttons, no fake device screenshots, no "download
   now"**. If you want a conversion surface, it is a waitlist or a self-host CTA —
   honestly labeled.
2. **Features marked premium/unbuilt in `PRICING.md` §1a stay marked.** Challenges,
   programs and the coach-companion are not live. Do not list them as present tense.
3. **No invented competitor claims.** `PRICING.md` §2 grounds **Whoop and Oura only**,
   with dated prices. **There is nothing in this repo about Bevel or any other app** —
   so you may not characterise them. Either compare against what §2 actually cites, or
   make the comparison categorical ("subscription-gated trackers", "uncited AI coaches")
   without naming a company you have no evidence about. Do not go look them up and do
   not guess. An unfair comparison would undermine the exact claim the page is making.
4. **Cited numbers carry their source and date**, exactly as §2 does. If §2 says prices
   are current as of a date, the page says so too.
5. **No composite marketing score, no invented statistics, no fake testimonials, no
   fabricated user counts.** If you need social proof and have none, the page ships
   without social proof.

If honesty and persuasiveness conflict anywhere, honesty wins and you flag the
tension in your report rather than resolving it in the copy's favour.

## What to cover
- **The hook** — the honesty thesis, in a sentence that doesn't sound like a manifesto.
- **How it's different** — the three differentiators (`PRICING.md` §1, end of section):
  free hardware-life tracking · the honesty contract (cited or it doesn't ship) ·
  own-your-data / self-hostable. Show, don't assert: the most persuasive element on
  this page is a **rendered example of the product refusing to answer** or saying "not
  enough data" — no competitor's landing page can show that.
- **The science layer** — the metrics from `PRICING.md` §1, and the fact that each
  method is cited to primary research (Jurca, Banister TRIMP, Phillips SRI, Gompertz).
  Named methods signal rigor better than adjectives do.
- **Personal science** — FDR-validated correlations and personal cutoffs; §1 calls this
  "a rigor most consumer apps don't attempt". The caffeine-cutoff example is concrete
  and lands.
- **The tier split** — from §1a. Lead with what's FREE, because "we don't paywall your
  own data" is the wedge. Pricing per §0.
- **A closing disclaimer** — required. Healthee is not a medical device; it does not
  diagnose, treat, or prevent disease; it is derived from consumer wearable data with
  stated confidence; it is not a substitute for professional medical advice; the coach
  refuses medical/diagnostic questions by design. Write it as prose that belongs to
  this brand — plain, unhedged, unashamed — not boilerplate in 9px grey. A product
  built on honesty should present its limits in the same voice as its strengths.

## Craft bar
- **Light mode primary, dark mode secondary.** Both fully designed, neither an
  afterthought. Respect `prefers-color-scheme`; ship a toggle.
- **Static output** (`output: 'static'`), zero runtime JS beyond the theme toggle —
  Astro ships none by default; keep it that way. **No CDNs, no external fonts, no
  trackers, no analytics**: everything self-hosted at build time. Any font is
  bundled locally or it's the system stack. ("Own your data" cannot be the pitch on
  a page that phones home to three third parties.)
- Responsive; no horizontal scroll at any width. Real semantic HTML, accessible
  contrast, keyboard-navigable, `prefers-reduced-motion` honored.
- Typography and spacing carry the premium feel — not gradients, glassmorphism, or
  decorative animation. Motion only where it clarifies.
- Data-dense where it earns it. This audience respects being trusted with detail.

## Output
The Astro project at `apps/web/`, building clean (`npm run build`) with a README
covering dev/build/deploy. Then a short report: which claims you sourced and from where, anything
you deliberately left out, and any place you felt the honest version was weaker copy
than the dishonest one. **That last list is the one I most want to read.**
````
