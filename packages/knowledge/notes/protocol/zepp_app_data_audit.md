---
title: Zepp/Amazfit app data-surface audit — what the Helio Strap actually exposes
status: IN PROGRESS (static APK analysis done; dynamic capture pending)
app: com.huami.watch.hmwatchmanager 10.4.0-play (updated 2026-06-02), targetSdk 36
device_under_test: Amazfit Helio Strap, fw 0.132.24.2, MAC DB:98:1F:80:4C:3D
apk_location: tools/zepp_re/apk/{base.apk, split_arm64.apk}  (gitignored — large)
tooling: jadx 1.5.0 at tools/zepp_re/jadx; dex at tools/zepp_re/dex; native libs tools/zepp_re/libs
purpose: >
  Verify independently (not trusting HelioCore/GB) what data types the device
  produces and can be pulled, to find anything the reimplementations miss.
---

# TL;DR — HelioCore/GB are INCOMPLETE

HelioCore (`HelioLegacyParser`) pulls: HR, HRV(avg), SpO2(spot), skin-temp,
stress, sleep-resp-rate, activity. The official app's sync engine
(`com.huami.device.core.sync.impl.job.milible`) defines richer typed data
that neither HelioCore nor Gadgetbridge attempt:

| Data type (app enum) | Variants | HelioCore? | Note |
|---|---|---|---|
| AtrialFibrillationType | AF, AF_ACC, AF_PPG, **PPG_RR** | ❌ | AFib episodes; **PPG_RR = raw beat-to-beat intervals** (true HRV source) |
| BloodOxygenType | CLICK, **OSA_PROCESS, OSA_EVENT, ODI** | partial | **Sleep apnea** (OSA) events + **Oxygen Desaturation Index**; HelioCore only does spot SpO2 |
| PressureType (stress) | ALL_DAY, SINGLE | partial | all-day continuous stress, not just single |
| BodyTemperatureType | — | ❌ | continuous body temp (distinct from skin-temp delta) |
| (capability) SUPPORT_ATRIAL_FIB | feature gate | — | app gates AFib per-device; strap is PPG → likely supported |

(Many other `*Type` classes exist — golf/boating/running-dynamics/etc. — but
those are for other devices; the strap won't have the hardware.)

# Confirmed protocol facts (vendor-verified)

- Native `libdevice-encrypt.so` exports `ecdh_generate_keys`,
  `ecdh_shared_secret`, `ecdsa_sign/verify`, bridged via JNI class
  `com.huami.core.device.feature.encrypt.impl.KeyShareApiImpl`
  (`generatePrivateKeyExternal` / `generatePublicKeyExternal`).
  → confirms the **same ECDH key-share handshake** that
  `research/protocol/zeppos_ble_handshake.md` describes (from GB + HelioCore).
- App is **hardened**: `libantidebug-lib.so` + `libantirepack-lib.so`
  (anti-debug + anti-repackaging) → Frida/repackaging will fight integrity
  checks. Static + dynamic-HCI-snoop is the lower-friction route.
- App is **multi-runtime**: Kotlin (25 dex, decompilable), Flutter
  (`libapp.so` Dart AOT + `libflutter.so`), React Native (`libhermes.so`,
  `libfabricjni.so`). Most device/sync logic is in Kotlin (good for jadx).
- Biometric algo libs (native, raw-signal → metric): `libHealthCare.so`,
  `libdataProcess.so`, `libcardioRecognizer*`, `libJhmSignal.so`,
  `libBodyfat.so`, `libemotion_algo.so`.

# BLE characteristics referenced by the app (superset of HelioCore's)

All under Huami service base `…-0000-3512-2118-0009af100700` unless noted.
HelioCore uses only: 0016/0017 (chunked), 0004/0005 (activity), 2A37, 2A19.
App ALSO references: **0010/0011, 0022/0023/0024**, and a separate
**fed0/fed1/fed2** service. ⚠️ The app is multi-device — these may not all
exist on the Helio Strap. MUST be confirmed by GATT enumeration of the
actual strap (below).

# Key code locations (in the APK, for deeper digs)

- Sync engine: `com.huami.device.core.sync.impl.job.milible` (+ `/type/`,
  `/callback/`) — the per-type fetch jobs.
- BLE transport/channels: `com.huami.bluetooth.profile.channel.module.syncable`
  (Serializer, DeviceDataRecover).
- Health store (HealthKit-style): `com.huami.health.matrix.core.database.table`
  (QuantitySamples / CategorySamples / CorrelationsSamples / Samples).
- Encrypt JNI: `com.huami.core.device.feature.encrypt.impl.KeyShareApiImpl`.

# Still to do

## Static (no device)
- [ ] Enumerate the COMPLETE `milible/type/*` set + the per-type **numeric
      sync codes** + how each is requested (decompile the milible job classes).
- [ ] Map the Helio Strap's **capability bitmask** → which types are actually
      enabled for THIS device (find the strap's device-config/feature set).
- [ ] Decode the `*Type` → characteristic/endpoint routing (0004/0005 vs
      0016/0017 vs the unknown 0010/0022/fed0).

## Dynamic (DEFINITIVE — needs the phone + the strap on-wrist)
- [ ] **GATT enumeration** of the actual strap (nRF Connect / `gatttool`)
      → the true list of services/characteristics it exposes. Resolves the
      0010/0022/fed0 question.
- [ ] **HCI snoop log** of a full `hmwatchmanager` sync (Dev Options →
      Bluetooth HCI snoop log) → Wireshark → the exact data-type requests +
      responses the official app pulls from THIS strap, incl. whether
      AFib/OSA/ODI/body-temp actually flow. This is ground truth.
- [ ] Diff the captured set against HelioCore's parser → final gap list →
      extend the Flutter port's fetch loop to cover the extras.

# Dynamic capture results (2026-06-04) — HCI snoop of a live hmwatchmanager sync

Captured via `adb bugreport` (Android 16, non-root) → btsnoop_hci.log; parsed
with `tools/zepp_re/parse_btsnoop.py`. Capture artifacts in `tools/zepp_re/capture/`
(gitignored).

## Strap's REAL GATT table (ground truth)

Services: 1800, 1801, 180a, **fee0** (Huami main, 0x35-0x50), 1530 (OTA),
180d (HR), **fee1**, 180f (battery).

Huami chars actually present on the strap (suffix -…-0009af100700):
`0001, 0002, 0004, 0005, 0006, 0016, 0017, 0023, 0024, 0025, 1531, 1532`
plus standard `2a37` (HR), `2a38`, `fedd`, `fede`, `2a19` (battery).

→ Resolves the APK ambiguity: `0023/0024/0025/0001/0002/0006` ARE real on the
device (HelioCore ignores them). `0010/0011/0022` and `fed0/fed1/fed2` are NOT
on the strap — they were other devices in the multi-device app.

## Handshake — validated LIVE, byte-for-byte with the spec

```
TX 0x0082 len=52  04020002 + <48B app pubkey>            (Step 1)
RX 0x0082 len=67  100401 + <16B random> + <48B dev pubkey> (Step 2)
TX 0x0082 len=33  05 + <16B enc1> + <16B enc2>            (Step 4)
RX 0x0082 len=3   100501                                  (AUTH SUCCESS)
```
Our ported auth (research/protocol/zeppos_ble_handshake.md) is correct.

## Sync choreography (post-auth, over chunked 0016/0017)

- `0x0047` set-time: `05 ea07 06 04 0a 31 25 …` = 2026-06-04 10:49:37.
- `0x0016` data-sync control: `04 01 0c d1000000 9a000000 12000000`
  = **209 / 154 / 18** records ready (3 data types); `05 NN` iterate, `07 …` EOF.
- `0x0029` sync range: two timestamps (2026-05-24 → 2026-06-02).
- `0x0028` device status/config (plaintext).
- **`0x000a` and `0x0019` = AES-encrypted** — the bulk health samples flow here.

## KEY LIMITATION — passive capture can't decrypt the payloads

The session key is `sessionAES = sharedEC[8:24] ^ authKey`, where `sharedEC`
derives from the APP's *ephemeral* ECDH private key — which never goes on the
wire. So a passive HCI snoop of the OFFICIAL app yields GATT + handshake +
plaintext metadata, but NOT the plaintext of the encrypted health channel.

→ To read AFib/OSA/ODI/PPG_RR/body-temp bytes, decrypt OUR OWN authenticated
session: our Flutter app generates the private key, so it knows the session
key. Build the app → replay the observed endpoint commands on `0x000a` →
decrypt our own responses → map bytes to the static type vocabulary. The app
is both the goal AND the instrument that finishes the RE.
(Alternative: Frida-hook the decrypt fn in the app, but it's hardened —
antidebug + antirepack — so own-session decryption is the lower-friction path.)

# Tier-2 fetch codes discovered (2026-06-04) — raw dumps for decoding

Probing fetch codes 0x00–0x4f on the plaintext 0004 channel found 4 unknown
codes with data (so AFib/OSA/etc. are MORE FETCH CODES, not encrypted services):

- **0x4e** (36 recs) — 9-byte records: `sec(u32 LE) + 0x16 + value(u32 LE)`.
  Sample: `3cf01d6a 16 a71c0000` (sec=0x6a1df03c, val=0x1ca7=7335). Values
  ~3187–7335, sparse/episodic. AFib-episode / OSA-event / ODI candidate.
- **0x27** (486) — `0x02` version + `sec(u32)` + float32 LE array, floats
  negative ~−10..−14 (recurring 0x..c1 top byte). Sample after version:
  `d4ce1e6a 805a235a c1998e57 c1...`.
- **0x3b** (1370) — PROTOBUF (`0801 1000 1828 20be01 2888 0a …` field tags).
  A summary/daily structure.
- **0x4a** (5792) — large mostly-zero sparse buffer, `sec` header
  (`a8cf1d6a f0690000 0000…` then long zero run). PPG-RR-like high-res sparse.

NEXT to label them: decompile the APK milible parsers per type
(AtrialFibrillation / BloodOxygen{OSA,ODI} / Pressure / BodyTemperature) and
match each byte format. The codes + dumps above are the RE starting point.

# Workout summary format (fetch 0x05) — VERIFIED 2026-06-04

The Helio Strap's workout summary is **protobuf** (newer than GB's fixed-offset
`HuamiActivitySummaryParser`). Each summary in the 0x05 stream is preceded by a
2-byte record header (`00 80`) then a protobuf message starting with the version
field. Split the stream on the version-field marker `0a 03 32 2e` ("2.").

Top-level field map (VERIFIED against a real workout: 2026-05-01, duration
6:49=409s, 53 kcal, avg HR 122):
```
f1  string  version ("2.1")
f2  { f1 = startTime (epoch s),  f3 = sportType }
f7  { f1 = durationSec }              ✓ 409 = 6:49
f16 { f1 = calories }                 ✓ 53
f19 { f1 = avgHr, f2 = maxHr, f3 = minHr }   ✓ avg 122; max 140 (summary)
f11 { f1,f2 floats } = distance / speed (unconfirmed — no-distance workout)
```
NOTE: the summary's max HR (f19.f2=140) is slightly below the app's displayed
max (144) — the app's peak comes from the per-second detail track (0x06); the
summary stores a smoothed max. Sport-code table (e.g. code 44) is in the APK,
not yet mapped. Dart impl: `app/lib/ble/workout_parser.dart`.

# Net answer to "is HelioCore missing data?"

YES, provably: AFib (incl. raw PPG_RR intervals), sleep-apnea OSA events + ODI,
all-day stress, body temperature — all in the device's data model + capability
gates, none captured by HelioCore. Exact byte formats: decode via our own
decrypting app (next phase).

Related: research/protocol/zeppos_ble_handshake.md
