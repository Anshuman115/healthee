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

Notes:
- `compressHTML: false` in `astro.config.mjs` is REQUIRED — Astro's default
  compression strips whitespace at inline-tag boundaries and glues words to
  citations ("or itdoesn't").
- `404.astro` backs the `not_found_handling: "404-page"` setting.
- After any change, grep `dist/` for `http(s)://` — the only allowed hits are
  the two cited competitor pricing pages, the healthz example inside the
  self-host snippet, and the SVG namespace.
