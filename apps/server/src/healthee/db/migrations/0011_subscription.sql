-- 0011_subscription — the entitlement row (Phase 6.6a, MULTI_USER.md §12.2).
--
-- ONE row per owner, and it is the SOLE source of truth for "may this person use
-- the AI layer". §12.7's threat model is that every client is adversarial, so the
-- answer may never come from a JWT claim, a request field, or anything the app
-- could be talked into writing — it comes from here, looked up per request.
--
-- Three deliberate departures from §12.2's sketch, each of which the sketch would
-- have got wrong:
--
--   * **ON UPDATE CASCADE**, which the sketch omits. `db/claim_sentinel.py` re-keys
--     the sentinel owner with a single `UPDATE app_user SET id = …` and relies on
--     every FK to `app_user(id)` carrying the cascade. A FK without one does not
--     silently skip — it ERRORS, taking the whole claim down. That is exactly what
--     `0006` had to go back and fix for `device_token`, and shipping the same defect
--     a second time in the same repo would be inexcusable. `ON DELETE CASCADE` is
--     the sketch's and is kept: deleting an owner deletes their entitlement.
--
--   * **The status vocabulary is a CHECK**, not a comment. `core/entitlement.py`
--     decides premium from this string; a typo'd `'activ'` would read as "not
--     premium" and silently wall a paying owner out. The constraint turns that into
--     a write that fails loudly. Same argument `0009` made for `challenge.status`.
--
--   * **`granted_by` and `note`** — two columns the sketch has no room for, because
--     it assumes a billing provider. 6.6a has no provider ([D4] is open): the only
--     writer today is the committed ops module `db/grant_premium.py`, run by a human
--     naming a UUID. WHO granted this and WHY is the audit trail for a hand-made
--     entitlement, and "we will remember" is not one. A webhook (6.6b) writes
--     `provider`/`provider_ref` instead and leaves these null.
--
-- Privileges: the app role gets **SELECT and nothing else** on this table
-- (`provision_app_role._READ_ONLY_TABLES`), which closes §12.7's "client-supplied
-- proof of payment" loophole at the database rather than in a code review — the
-- request path physically cannot mint entitlement. That revoke lives in the
-- provisioning module because the app role's NAME is per-deployment env config and
-- a migration cannot know it.
--
-- Replay-safe: IF NOT EXISTS + a policy dropped by name first. One statement per
-- `;`, no DO blocks (the runner splits on `;`).

CREATE TABLE IF NOT EXISTS subscription (
  user_id            UUID PRIMARY KEY REFERENCES app_user(id)
                       ON UPDATE CASCADE ON DELETE CASCADE,
  status             TEXT NOT NULL DEFAULT 'none',
  plan               TEXT,
  provider           TEXT,
  provider_ref       TEXT,
  trial_end          TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  granted_by         TEXT,
  note               TEXT,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE subscription DROP CONSTRAINT IF EXISTS subscription_status_chk;
ALTER TABLE subscription ADD CONSTRAINT subscription_status_chk
  CHECK (status IN ('none', 'trialing', 'active', 'past_due', 'canceled', 'expired'));

-- The same tenant policy every other owned table carries (0008). It is the backstop
-- under the explicit `AND user_id = %s`, not a replacement for it — and here it also
-- means a read of somebody else's entitlement returns nothing rather than a boolean.
ALTER TABLE subscription ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS subscription_tenant ON subscription;
CREATE POLICY subscription_tenant ON subscription FOR ALL
  USING      (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('healthee.user_id', true), '')::uuid);

COMMENT ON TABLE subscription IS
  'The server-owned entitlement row: one per owner, the SOLE source of truth for '
  'premium access (MULTI_USER.md 12.2/12.7). Never derived from a client claim.';
COMMENT ON COLUMN subscription.current_period_end IS
  'Paid-through instant. is_premium() requires now() < this for EVERY status (a '
  'trialing row uses trial_end instead, and past_due adds a dunning grace window). '
  'An entitlement with no end instant is not premium — "granted once, forgotten" '
  'is the loophole this column exists to close.';
COMMENT ON COLUMN subscription.granted_by IS
  'Who granted a hand-made entitlement (db/grant_premium.py). Null for provider-driven rows.';
