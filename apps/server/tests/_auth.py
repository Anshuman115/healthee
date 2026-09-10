"""A Supabase-shaped access JWT for tests — the credential `/api/*` actually takes.

Until 2026-09-10 most endpoint tests authenticated with the single shared
`REALTIME_INGEST_TOKEN`, because a static string in a header is the least ceremony
a test can spend on auth. That branch is gone from `core.request_auth`, so those
tests now present what the product presents: a JWT the server verifies.

The token is **self-signed with the configured `SUPABASE_JWT_SECRET`** and never
reaches a live Supabase. That is the whole trick — `verify_supabase_jwt` picks its
algorithm list from the KEY SOURCE, so a shared secret configured means HS256
verification, and a test can mint a real credential for a real owner without a
network. `tests/test_supabase_asymmetric.py` covers the ES256 path Supabase
actually issues; this helper deliberately does not, because an endpoint test that
had to stand up a JWKS to read a number would be testing the wrong thing.

Not a pytest module (underscore-prefixed); imported by the test modules.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt

#: The audience `supabase_auth` requires, and Supabase's own default.
AUDIENCE = "authenticated"

#: The shared signing secret for tests. ONE value, long enough on purpose: PyJWT
#: warns on an HMAC key under 32 bytes, and a suite that prints a security warning
#: on every run is a suite whose warnings nobody reads.
SECRET = "healthee-test-jwt-secret-not-a-real-one"


#: How long a minted token lives. Twelve hours, not one, because several modules
#: build their header at IMPORT time and a slow full-suite run must not start
#: failing on expiry — a test that goes red because the clock moved teaches nothing
#: and costs an afternoon to read. `test_supabase_auth.py` owns expiry itself.
LIFETIME_HOURS = 12


def access_token(sub: UUID | str, secret: str, *, audience: str = AUDIENCE) -> str:
    """A signed access JWT naming `sub` as the owner."""
    return jwt.encode(
        {
            "sub": str(sub),
            "aud": audience,
            "exp": datetime.now(tz=UTC) + timedelta(hours=LIFETIME_HOURS),
        },
        secret,
        algorithm="HS256",
    )


def auth_header(sub: UUID | str, secret: str) -> dict[str, str]:
    """`{"Authorization": "Bearer <jwt>"}` for `sub`."""
    return {"Authorization": f"Bearer {access_token(sub, secret)}"}
