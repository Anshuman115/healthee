---
title: ZeppOS / Huami-2021 BLE auth handshake — Amazfit Helio Strap
status: reverse-engineered from Gadgetbridge source (2026-06-04)
device: Amazfit Helio Strap, firmware 0.132.24.2, MAC DB:98:1F:80:4C:3D
protocol_generation: ZeppOS / Huami-2021
source: Gadgetbridge (AGPLv3), codeberg.org/Freeyourgadget/Gadgetbridge
  - service/devices/huami/zeppos/services/ZeppOsAuthenticationService.java
  - service/devices/huami/operations/init/InitOperation2021.java
  - util/ECDH_B163.java, util/CryptoUtils.java
  - devices/huami/HuamiService.java (UUIDs)
  - devices/huami/zeppos/straps/AmazfitHelioStrapCoordinator.java
license_note: |
  Gadgetbridge is AGPLv3. Any code ported from it (esp. ECDH_B163 and the
  handshake) makes the derived app AGPLv3. Fine for personal/private use.
---

# Goal

Connect a self-built Flutter app directly to the Helio Strap over BLE,
authenticate using the auth key already extracted from the existing
Gadgetbridge install, and read live + historical sensor data — replacing
Gadgetbridge on the phone.

# Credentials (already in hand)

- **Auth key (16 bytes)**: stored in
  `data/gadgetbridge/db/Export_preference_device.xml` under
  `<String name="authkey">0x…</String>`. SECRET — never commit. The `0x`
  prefix + 32 hex chars decodes to the 16-byte `secretKey`.
- **MAC**: `DB:98:1F:80:4C:3D`
- **BLE advertised name**: `Amazfit Helio Strap` (no MAC suffix).

# Transport

- **BLE** (GATT). Helio Strap uses the default ZeppOS connection type =
  BLE (`ZeppOsBtleSupport`). The Bluetooth-Classic/RFCOMM path
  (`ZeppOsBtbrSupport`) applies only to forced-classic watches — not this.
- Flutter plugin: `flutter_blue_plus`.

## Cross-validated by a second implementation: HelioCore (Swift/iOS)

`github.com/a9eelsh/HelioCore` (GooseSwift, single-file ~1567 LOC) is an
independent native iOS reverse-engineering of THIS device. Its handshake,
chars, ECDH, and chunked codec match GB **byte-for-byte** — confirms the
spec below. It is the **recommended source to port from** (one clean Swift
file vs GB's many Java files). Key Swift symbols: `HuamiECDH` (pure-Swift
sect163k1), `HuamiChunkedEncoder/Decoder`, `AES128.ecbEncrypt`,
`ZeppAuthClient` (cloud login → auth_key), `HelioLegacyParser` (per-metric
decoders). NOTE: HelioCore has no LICENSE file — reference/learn from it,
do not vendor its code without asking the author.

## GATT characteristics

Base UUID suffix: `-0000-3512-2118-0009af100700`

| Role | UUID |
|---|---|
| Chunked-transfer WRITE (app → device) | `00000016-…-0009af100700` |
| Chunked-transfer READ/NOTIFY (device → app) | `00000017-…-0009af100700` |
| Activity-fetch CONTROL | `00000004-…-0009af100700` |
| Activity-fetch DATA | `00000005-…-0009af100700` |
| Firmware service (OTA, later) | `00001530-…-0009af100700` |
| Standard Heart Rate Measurement (live HR) | `2A37` |
| Standard Battery Level | `2A19` |

- **Live data + commands** → chunked transport (0016/0017), logical endpoints.
- **Historical sync** → activity-fetch control/data (0004/0005), the
  "legacy fetch" round protocol (per-type: temp/stress/spo2/HR/HRV/resp).
- **Proof-of-life shortcut**: subscribe to `2A37` for live HR, or read
  `2A19` battery — both standard GATT, available right after auth.

## Chunked transport framing (Huami2021)

Per chunk written to char 0016 (MTU ~247, `type: .withoutResponse`):
`[0x03, flags, 0x00, writeHandle, count]` then, **on the first chunk only**:
`uint32LE(totalPayloadLen) + uint16LE(endpoint)`, then the payload slice.
- flags: `0x01`=first, `0x02`=last, `0x04`=set with last, `0x08`=encrypted.
- `writeHandle` increments per message; `count` increments per chunk.
- Decoder reassembles on char 0017; if `encrypted` flag set, length is
  padded to a 16-byte boundary after +8 (post-auth frames). Auth frames
  (endpoint 0x0082) are unencrypted.

All logical "endpoints" (auth = `0x0082`, and every post-auth service)
are multiplexed over this single chunked WRITE/NOTIFY pair. So the first
thing to port after BLE connect is the **Huami2021 chunked encoder/decoder**
(`Huami2021ChunkedEncoder.java` / `Huami2021ChunkedDecoder.java`), which
frames `(endpoint, payload)` into characteristic writes and, after auth,
encrypts each frame with the session key + sequence number.

# The auth handshake (endpoint 0x0082)

Crypto primitives:
- **ECDH over curve B-163** (binary field GF(2¹⁶³)) — `ECDH_B163`.
  Private key = 24 bytes (192 bits), public key = 48 bytes.
- **AES/ECB/NoPadding** for the proof-of-knowledge step.

Command bytes: `CMD_PUB_KEY = 0x04`, `CMD_SESSION_KEY = 0x05`.
Response framing: `payload[0] = RESPONSE (0x10)`, `payload[1] = cmd echo`,
`payload[2] = status (SUCCESS=0x01; 0x25 = wrong auth key)`.

### Step 1 — app sends its public key (→ device)
1. `privateEC` = 24 random bytes.
2. `publicEC` = `ECDH_B163.ecdh_generate_public(privateEC)` (48 bytes).
3. Frame to send on endpoint 0x0082:
   `[0x04, 0x02, 0x00, 0x02] + publicEC[48]`  (52 bytes total).

### Step 2 — device replies with its random + public key (← device)
Response payload layout (after the 3-byte RESPONSE/cmd/status header):
- `remoteRandom`   = payload[3 .. 19]   (16 bytes)
- `remotePublicEC` = payload[19 .. 67]  (48 bytes)

### Step 3 — app derives the session key
1. `sharedEC = ECDH_B163.ecdh_generate_shared(privateEC, remotePublicEC)`.
2. `encryptedSequenceNumber = uint32_LE(sharedEC[0..4])`
   → initial sequence/nonce for the post-auth encrypted channel.
3. `secretKey` = the 16-byte auth key.
4. `sessionAES[i] = sharedEC[i + 8] ^ secretKey[i]`  for i in 0..16.
5. Stash `(encryptedSequenceNumber, sessionAES)` as the encryption params
   for all subsequent chunked frames.

### Step 4 — app proves it knows both keys (→ device)
1. `encRandom1 = AES_ECB_encrypt(remoteRandom, secretKey)`   (16 bytes).
2. `encRandom2 = AES_ECB_encrypt(remoteRandom, sessionAES)`  (16 bytes).
3. Frame: `[0x05] + encRandom1[16] + encRandom2[16]`  (33 bytes), endpoint 0x0082.

### Step 5 — device confirms (← device)
- `status == 0x25` → wrong auth key (abort).
- `status == SUCCESS` → authenticated; proceed to device init.

# B-163 curve parameters (for the Dart port of ECDH_B163)

tiny-ECDH port, B-163 only. Word arrays are little-endian uint32[6]
(163-bit + margin). Verbatim from `util/ECDH_B163.java`:

```
CURVE_DEGREE   = 163
ECC_PRV_KEY_SIZE = 24 ; ECC_PUB_KEY_SIZE = 48
polynomial = {0x000000c9, 0, 0, 0, 0, 0x00000008}   // x^163 + x^7 + x^6 + x^3 + 1
coeff_b    = {0x4a3205fd, 0x512f7874, 0x1481eb10, 0xb8c953ca, 0x0a601907, 0x00000002}
base_x     = {0xe8343e36, 0xd4994637, 0xa0991168, 0x86a2d57e, 0xf0eba162, 0x00000003}
base_y     = {0x797324f1, 0xb11c5c0c, 0xa2cdd545, 0x71a0094f, 0xd51fbc6c, 0x00000000}
base_order = {0xa4234c33, 0x77e70c12, 0x000292fe, 0, 0, 0x00000004}
```

# Auth-key acquisition — two working routes

1. **From the existing GB install (have it now)**: `authkey` in
   `data/gadgetbridge/db/Export_preference_device.xml`.
2. **Dynamic cloud login (huami-token flow)**, as HelioCore does and as
   THIS project already implements in Python (`sources/zepp_cloud/auth.py`,
   `ZeppSession`): email+password → access_token → login → **getDevices**,
   whose per-device payload includes `auth_key`. Huami API request bodies
   are AES-128-CBC-PKCS7 with the well-known constants
   key=`xeNtBVqzDc6tuNTh`, iv=`MAAAYAAAAAAAAABg`. The key is static per
   pairing — fetch once, cache, then BLE is fully offline.
   ⚠️ Cloud login bumps the phone's Zepp session (single-session policy) —
   but it's a one-time fetch, see [[zepp-cloud-single-session-conflict…]].

# Port plan (Dart / Flutter) — port from HelioCore, cross-check vs GB

1. **`ecdh_sect163k1.dart`** — port `HuamiECDH` (pure int math: gfMul,
   gfInv, ptAdd, ptDouble, ptMul; no platform deps). The only hard part.
   **Offline gate**: fixed private key → public key must match both the
   Swift and Java impls before touching BLE.
2. **`huami_chunk.dart`** — port `HuamiChunkedEncoder/Decoder` (framing above).
3. **`zeppos_auth.dart`** — the 5-step handshake (endpoint 0x0082).
4. **AES** — use `pointycastle`: AES/ECB/NoPadding (auth proof) +
   AES/CBC/PKCS7 (cloud login body).
5. **BLE** — `flutter_blue_plus`: scan name "Amazfit Helio Strap" → connect →
   discover services → handshake → subscribe `2A37` (live HR) for proof of life.
6. **Historical sync** — port `HelioLegacyParser` + the 0004/0005 round
   protocol; map decoded samples → POST `/ingest/realtime` + batch endpoints.

# Still to capture on the phone (verification, not blocking)

- **HCI snoop log** of a real GB↔strap connect (Dev Options → Bluetooth
  HCI snoop log) → Wireshark, to confirm the exact byte framing on the
  wire and the post-auth encrypted-frame format against the chunked codec.
- **GATT audit** via nRF Connect: dump every service/characteristic the
  strap advertises vs what GB reads → find anything GB doesn't expose.

# Validation idea (no device needed)

Port ECDH_B163 to Dart and check `ecdh_generate_public(privateEC)` matches
the Java implementation for a fixed private key — pin the math before
touching BLE.
