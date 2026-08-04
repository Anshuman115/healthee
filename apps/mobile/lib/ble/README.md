# `ble/` — the strap protocol layer

**The protocol is still empty.** What is here is `strap_scanner.dart` and its
`flutter_blue_plus` implementation: a MAC-matching advertisement scan, used by
pairing to prove the chosen strap is in range before its credentials are stored.
No connection, no handshake, no characteristic reads.

That distinction is worth keeping sharp. The scanner answers *is it here*; the
protocol answers *what does it have*, and only the second one needs the auth key.

The remaining dependencies are already pinned and resolved in `pubspec.yaml`
(`pointycastle`, `workmanager`) so that PR starts from a working set rather than
re-deciding versions. `pointycastle` is in use already — by `data/pairing/`, for
the Zepp login payload, which is unrelated cryptography on a different key.

## What still goes here

`auth`, `transport`, `fetcher`, `parsers` — version-guarded (Standards §3).

## The rules it is built under

- **Port the protocol verbatim from `~/projects/healthee-legacy`**, then verify
  against golden fixtures. It is proven code; CLAUDE.md's porting rule covers it
  explicitly. Do not "clean it up" on the way across.
- **Parsers are layout-versioned, sentinel-filtered (`0xFF`) and golden-tested**
  from real captured data. Byte offsets get an offset-table comment — this is the
  code CLAUDE.md means when it says byte-format code MUST carry layout comments.
- **Credentials come from `data/api/credentials.dart`**, never from a
  `--dart-define` — read them through `PairingRepository.pairedStrap()`, which
  returns a validated `PairedStrap` or null and treats half a pairing as none.
  They are written by `data/pairing/`, at pairing time, from the owner's Zepp
  account; `core/env.dart` explains at length why baking them in is what made
  the legacy app single-owner.
- **Sync failures reach sync health**, not just the log. A background failure
  that only prints is a feature that has silently stopped working — the legacy
  repo shipped five of those.

## Known gotchas, already paid for

- The `0xFF`-gap pager stall, and the `0x0016` daily-total override.
- The strap's daily step total has no durable raw table server-side; a re-derive
  destroys it. Capture-then-restore before any prod re-derive.
- Live stress arrives on the encrypted channel — `0x13` is already understood and
  does not need re-reverse-engineering.
