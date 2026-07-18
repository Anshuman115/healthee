// The landing Worker: static assets are served by the platform first; only
// non-asset routes (the waitlist API) reach this Hono app. Waitlist emails go
// to the existing Supabase project's Postgres (auth lives there too, so the
// list sits next to the accounts it will one day become) — never into the
// health database. The service-role key is a Worker secret; the browser only
// ever talks to THIS same-origin endpoint.
import { Hono } from 'hono';

type Env = {
  ASSETS: { fetch: (req: Request) => Promise<Response> };
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
};

const app = new Hono<{ Bindings: Env }>();

// Deliberately loose: real validation is "did they get the mail when we send
// it". This only rejects obvious garbage, capped at the RFC length.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

const htmlPage = (title: string, body: string, status = 200) =>
  new Response(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${title}</title><body style="font-family:system-ui;background:#171310;color:#f0e9df;display:grid;place-items:center;min-height:100vh;margin:0;padding:1.5rem;text-align:center"><div><h1 style="font-size:1.6rem;letter-spacing:-0.02em">${title}</h1><p style="color:#b3a996;max-width:26rem">${body}</p><p><a href="/" style="color:#e0704f">&larr; back to Healthee</a></p></div>`,
    { status, headers: { 'content-type': 'text/html; charset=utf-8' } },
  );

async function saveEmail(env: Env, email: string): Promise<boolean> {
  // PostgREST upsert with ignore-duplicates == INSERT ... ON CONFLICT DO
  // NOTHING, so a duplicate is indistinguishable from a fresh signup.
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/waitlist?on_conflict=email`, {
    method: 'POST',
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      'content-type': 'application/json',
      prefer: 'resolution=ignore-duplicates,return=minimal',
    },
    body: JSON.stringify({ email, source: 'landing' }),
  });
  return res.ok;
}

app.post('/api/waitlist', async (c) => {
  const contentType = c.req.header('content-type') ?? '';
  const isForm = contentType.includes('form');

  let email = '';
  let honeypot = '';
  if (isForm) {
    const body = await c.req.parseBody();
    email = typeof body.email === 'string' ? body.email : '';
    honeypot = typeof body.website === 'string' ? body.website : '';
  } else {
    const body = await c.req.json().catch(() => ({}) as Record<string, unknown>);
    email = typeof body.email === 'string' ? String(body.email) : '';
    honeypot = typeof body.website === 'string' ? String(body.website) : '';
  }

  email = email.trim().toLowerCase();

  // A filled honeypot gets the same success as everyone else — just no row.
  if (!honeypot) {
    if (!EMAIL_RE.test(email) || email.length > 254) {
      return isForm
        ? htmlPage('That address didn’t look right.', 'Check the email and try again — honest mistakes happen.', 422)
        : c.json({ ok: false, error: 'That email doesn’t look right.' }, 422);
    }
    const saved = await saveEmail(c.env, email);
    if (!saved) {
      // The honest product doesn't pretend a failed save worked.
      return isForm
        ? htmlPage('That didn’t go through.', 'Something on our side hiccuped. Try again in a minute.', 503)
        : c.json({ ok: false, error: 'Couldn’t save that right now — try again in a minute.' }, 503);
    }
  }

  return isForm
    ? htmlPage('You’re on the list.', 'We’ll write when sign-ups open — nothing else, no newsletter.')
    : c.json({ ok: true });
});

// Anything else that reached the Worker isn't an asset — let the assets
// runtime answer it so the 404 page (and its handling) stays canonical.
app.all('*', (c) => c.env.ASSETS.fetch(c.req.raw));

export default app;
