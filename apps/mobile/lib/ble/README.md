# `ble/` — the strap protocol layer

Empty. This lands next, and its dependencies are already pinned and resolved in
`pubspec.yaml` (`flutter_blue_plus`, `pointycastle`, `permission_handler`,
`workmanager`) so that PR starts from a working set rather than re-deciding
versions.

## What goes here

`auth`, `transport`, `fetcher`, `parsers` — version-guarded (Standards §3).

## The rules it is built under

- **Port the protocol verbatim from `~/projects/healthee-legacy`**, then verify
  against golden fixtures. It is proven code; CLAUDE.md's porting rule covers it
  explicitly. Do not "clean it up" on the way across.
- **Parsers are layout-versioned, sentinel-filtered (`0xFF`) and golden-tested**
  from real captured data. Byte offsets get an offset-table comment — this is the
  code CLAUDE.md means when it says byte-format code MUST carry layout comments.
- **Credentials come from `data/api/credentials.dart`**, never from a
  `--dart-define`. The MAC and AUTHKEY are per-owner secrets from the Zepp
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
