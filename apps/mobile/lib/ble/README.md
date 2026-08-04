# `ble/` — the strap protocol layer

Connect to the paired strap, authenticate, pull a day, hand back typed data.
That is the whole of it: **nothing here writes to the local store and nothing
here draws a screen.** Both are the next package.

Ported from `~/projects/healthee-legacy/app/lib/ble/` under CLAUDE.md's porting
rule — proven protocol code comes across verbatim, and what changed is only what
the new architecture forces: injection, logging, typing, and file layout.

## What is here

```
ble/
  strap_client.dart         the way in — credentials → connect → handshake
  strap_session.dart        one authenticated connection: channels, routing, totals
  strap_sync.dart           the fetch plan: which types, in what order, from when
  vitals.dart               one definition per vital, over one sync's samples
  strap_failure.dart        every named failure · strap_exception.dart wraps them
  strap_scanner.dart        the presence check used by PAIRING (not the protocol)
  bluetooth_strap_scanner.dart
  crypto/     ecdh_sect163k1 · huami_crypto (AES-ECB, CRC-32, auth-key decode)
  transport/  huami_chunk (the codec) · huami_comms · huami_time · zeppos_auth
              strap_link (the injectable radio) · bluetooth_strap_link
  fetch/      activity_fetcher — the round protocol and the 0xFF gap-skip
  parsers/    activity_parser · sleep_parser · workout_parser
  models/     strap_sample · sleep_session · workout · device_daily_totals
              strap_data · strap_sync_window · strap_sync_result
```

## Where the credentials come from

`PairingRepository.pairedStrap()` — the platform keystore, written at pairing
time. **Never a `--dart-define`.** The legacy app read `MAC` and `AUTHKEY` from
`String.fromEnvironment`, which is what made it a single-owner app; `core/env.dart`
explains that at length. Nothing in this directory calls `String.fromEnvironment`,
and a file here that starts to is carrying the old bug forward.

## What the tests prove, and what they do not

There are **no captured BLE frames in this repo**, so no test here is
verification against hardware. Two honest tiers instead:

| tier | what it means | where |
|---|---|---|
| **spec-derived** | the fixture is built from an independent written source — the handshake doc, a published standard, or a layout comment that is not the code under test | crypto · chunk codec · handshake · huami_time · sleep_parser · workout_parser · fetch round protocol · parts of activity_parser |
| **regression pin** | the layout exists only in the parser, so the fixture pins today's behaviour and nothing more | activity_parser's byte positions (0x01, 0x2E, the 6-byte HR family, 0x38, 0x49, 0x25) · `StrapData` · `Vitals` |

The published vectors are worth naming: AES-128/ECB against **FIPS-197 C.1**,
CRC-32 against the catalogued **`"123456789"` → `0xCBF43926`**, and the B-163
base point re-typed from the handshake doc and checked against the constants
compiled into `EcdhSect163k1`.

`test/ble/_fake_strap.dart` is the device half of the protocol, written from the
document. The handshake, the encrypted post-auth channel and the fetch rounds
all run end to end against it.

## The two production lessons this layer carries

- **The `0xFF` sentinel and the pager stall.** The per-minute stream stalls and
  leaves `0xFF` in minutes it never wrote. Parsers drop it; the fetcher steps
  `since` forward by the round's minute count so the pager crosses a dead block
  instead of asking for it forever. `project_steps_stuck_pager_stall` is why.
- **The `0x0016` daily total is authoritative; the per-minute sum is not.** The
  server learned this expensively (#121) and now has `device_daily_total` as its
  durable home. `StrapSyncResult.dailyTotals` carries the counter out of this
  layer, and the caller must push it — dropping it on the phone would recreate
  the loss one layer up.

## Known deviations from the legacy code

All reported, none silent:

1. `huami_chunk.dart` keeps the encoder AND the decoder in one file. They are one
   wire codec; splitting them would put the two halves of a format in two files
   that can drift.
2. Control writes and the auth proof were fire-and-forget. They now log through
   `AppLog` and end the operation with a named reason instead of leaving an
   unhandled async error (Standards §1 — errors are never swallowed).
3. The daily-totals request is sent **before** the activity-channel check, not
   after. Legacy returned early when `0x0004`/`0x0005` were missing, so a strap
   that could still report its counter reported nothing.
4. The reply is now **awaited** (bounded, 5 s) rather than hoped for.
5. Frame hex dumps are gone. Endpoint and length only — see
   `test/ble/ble_secrecy_test.dart`.
6. `toJson`/`fromJson` on `SleepSession` and `Workout` did not come across; they
   served the legacy store, which drift supersedes.
