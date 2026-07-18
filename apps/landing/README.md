# Healthee — landing page

The public landing page: a static Astro 7 + Tailwind v4 site, fully
self-contained (no external fonts, CDNs, trackers, or third-party scripts).
Design + binding content rules: **[DESIGN.md](DESIGN.md)** — read it before
changing anything; the page is bound by the product's honesty contract.

## Develop

```sh
npm install
npm run dev        # local dev server
npm run build      # static build → dist/
npm run preview    # serve the built dist/
```

## Deploy (Cloudflare)

Ships as a Cloudflare **Workers static-assets** site (config in
`wrangler.jsonc`, worker name `healthee-landing`).

```sh
npx wrangler login   # once per machine (or set CLOUDFLARE_API_TOKEN)
npm run deploy       # astro build && wrangler deploy
```

First deploy serves on the account's `*.workers.dev` subdomain. To attach the
real hostname, uncomment the `routes` line in `wrangler.jsonc` with the chosen
domain (the zone must be on the same Cloudflare account) and deploy again —
wrangler creates the DNS record.

### Waitlist (one-time setup)

The page's form posts to the same-origin `POST /api/waitlist`, handled by the
Hono app in `src/worker.ts`, which stores emails in the **Supabase project's**
Postgres (next to auth — never the health DB) via the service-role key.

1. Run `waitlist.sql` once in the Supabase SQL editor (RLS on, no policies —
   only the service role can touch the table).
2. `npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY` (paste the key).
3. Local dev: put `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` in `.dev.vars`
   (gitignored), then `npx wrangler dev`.

Endpoint behavior: lowercased + deduped (`on_conflict=email`, ignore-duplicates
— a duplicate is indistinguishable from a new signup), honeypot field returns
fake success without a row, invalid → 422, failed save → an honest 503 (never a
fake "you're on the list"), form-encoded posts get a tiny HTML page so the form
works without JavaScript.

Notes:
- `compressHTML: false` in `astro.config.mjs` is REQUIRED — Astro's default
  compression strips whitespace at inline-tag boundaries and glues words to
  citations ("or itdoesn't").
- `404.astro` backs the `not_found_handling: "404-page"` setting.
- After any change, grep `dist/` for `http(s)://` — the only allowed hits are
  the two cited competitor pricing pages, the healthz example inside the
  self-host snippet, and the SVG namespace.
