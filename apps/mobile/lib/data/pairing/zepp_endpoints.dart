/// The Zepp account API, exactly as the proven Python reference speaks it.
///
/// Every URL, form field and header below is transcribed from
/// `huami_token/constants.py` — the library the legacy `healthee zepp-login`
/// command has been running against a real account. Standards §5's porting rule
/// applies: this is proven protocol code, so it is copied faithfully rather than
/// tidied. A field that looks redundant (`app_name` *and* `appname`; `r` sent
/// twice) is redundant in the reference too, and Zepp's gateway rejects requests
/// that drop them.
///
/// ## Nothing here is a secret
///
/// The AES key and IV are fixed constants of the Zepp Android client, published
/// in every open-source implementation of this flow. They obfuscate the login
/// payload in transit; they do not protect it, and treating them as a secret
/// would be security theatre. What IS secret is the password they wrap, the
/// tokens that come back, and the strap's auth key — none of which appear in
/// this file, and none of which may be logged (`zepp_client.dart`).
///
/// ## Region
///
/// `us2` / `US` / `us-west-2` throughout, matching the reference. A user whose
/// account lives in another region can fail here for a real reason, and the
/// failure taxonomy names that case rather than guessing at a fix
/// (`pairing_failure.dart`, `zeppApiChanged`).
library;

import 'dart:typed_data';

/// The three endpoints the pairing flow calls, in order.
abstract final class ZeppUrls {
  /// Step 1 — exchange email + password for an access token. Answers with a
  /// redirect; the tokens are in the `Location` header's query.
  static const String tokens = 'https://api-user-us2.zepp.com/v2/registrations/tokens';

  /// Step 2 — exchange the access token for an app token and a user id.
  static const String login = 'https://api-mifit-us2.zepp.com/v2/client/login';

  /// Step 3 — the account's bound devices. `{user_id}` is substituted.
  static const String devices = 'https://api-mifit.zepp.com/users/{user_id}/devices';

  /// [devices] with the owner's id filled in.
  static String devicesFor(String userId) => devices.replaceFirst('{user_id}', userId);
}

/// AES-CBC parameters for the step-1 payload. Fixed constants of the Zepp client.
abstract final class ZeppCipher {
  /// The 16-byte key, ASCII `xeNtBVqzDc6tuNTh`.
  static final Uint8List key = Uint8List.fromList('xeNtBVqzDc6tuNTh'.codeUnits);

  /// The 16-byte IV, ASCII `MAAAYAAAAAAAAABg`.
  static final Uint8List iv = Uint8List.fromList('MAAAYAAAAAAAAABg'.codeUnits);
}

/// Zepp's client-channel magic string. Sent as a header and as a query param.
const String _zeppChannel = 'a100900101016';

/// The Zepp Android client version this flow impersonates.
///
/// Version-shaped strings appear in five places and must agree; a mismatch is
/// one of the ways Zepp rejects a request. Named once so they cannot drift.
const String _appVersion = '9.12.5';
const String _clientVersion = '151689_$_appVersion';
const String _buildStamp = '202509151347';
const String _userAgent = 'Zepp/$_appVersion (Pixel 4; Android 12; Density/2.75)';

/// Form bodies. The ORDER of these entries is part of the wire format.
///
/// The reference builds them from a Python dict and url-encodes it in insertion
/// order, so a `List` of pairs is the faithful representation — a Dart `Map`
/// would preserve order too, but only by accident of implementation, and
/// `token` genuinely appears twice, which a map cannot express at all.
abstract final class ZeppForms {
  /// Step 1's body, before encryption. [email] and [password] fill the blanks.
  ///
  /// Returned as pairs and never held anywhere: the caller encodes, encrypts and
  /// drops it. See `zepp_client.dart` for why the plaintext never reaches a log.
  static List<(String, String)> tokens({
    required String email,
    required String password,
  }) => [
    ('emailOrPhone', email),
    ('state', 'REDIRECTION'),
    ('client_id', 'HuaMi'),
    ('password', password),
    ('redirect_uri', 'https://s3-us-west-2.amazonaws.com/hm-registration/successsignin.html'),
    ('region', 'us-west-2'),
    // Sent twice on purpose — Python's `urlencode(doseq=True)` over a list.
    ('token', 'access'),
    ('token', 'refresh'),
    ('country_code', 'US'),
  ];

  /// Step 2's body. [accessToken] is step 1's `access`; [deviceId] is a fresh
  /// random UUID per attempt, as the reference generates one per login.
  static Map<String, String> login({
    required String accessToken,
    required String deviceId,
  }) => {
    'code': accessToken,
    'device_id': deviceId,
    'device_model': 'android_phone',
    'app_version': _appVersion,
    'dn':
        'api-mifit.zepp.com,api-user.zepp.com,api-mifit.zepp.com,api-watch.zepp.com,'
        'app-analytics.zepp.com,auth.zepp.com,api-analytics.zepp.com',
    'third_name': 'huami',
    'source': 'com.huami.watch.hmwatchmanager:$_appVersion:151689',
    'app_name': 'com.huami.midong',
    'country_code': 'US',
    'grant_type': 'access_token',
    'allow_registration': 'false',
    'lang': 'en',
    'countryState': 'US-NY',
  };
}

/// Request headers, per step.
abstract final class ZeppHeaders {
  /// Step 1. `x-hm-ekv: 1` is what tells the gateway the body is encrypted.
  static Map<String, String> tokens() => {
    'app_name': 'com.huami.midong',
    'appname': 'com.huami.midong',
    'cv': _clientVersion,
    'v': '2.0',
    'appplatform': 'android_phone',
    'vb': _buildStamp,
    'vn': _appVersion,
    'user-agent': _userAgent,
    'x-hm-ekv': '1',
    'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
  };

  /// Step 2. The reference sends browser headers here, not Android ones.
  static Map<String, String> login() => {
    'app_name': 'com.huami.webapp',
    'appname': 'com.huami.webapp',
    'origin': 'https://user.zepp.com',
    'referer': 'https://user.zepp.com/',
    'user-agent':
        'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
    'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.5',
  };

  /// Step 3. [appToken] authenticates; [requestId] is a fresh UUID per call.
  ///
  /// `hm-privacy-ceip` is Zepp's telemetry opt-in and the reference sends
  /// `true`. We send **false**: this app exists so health data stays on the
  /// owner's own hardware, and opting them into a vendor's analytics on the way
  /// past would contradict that. It is a header on a device-list read, so it
  /// costs nothing to say no.
  static Map<String, String> devices({
    required String appToken,
    required String requestId,
  }) => {
    'hm-privacy-diagnostics': 'false',
    'hm-privacy-ceip': 'false',
    'country': 'US',
    'appplatform': 'android_phone',
    'x-request-id': requestId,
    'timezone': 'Europe/London',
    'channel': _zeppChannel,
    'vb': _buildStamp,
    'cv': _clientVersion,
    'appname': 'com.huami.midong',
    'v': '2.0',
    'vn': _appVersion,
    'apptoken': appToken,
    'lang': 'en_US',
    'user-agent': _userAgent,
  };
}

/// Step 3's query string.
abstract final class ZeppQuery {
  /// The device-list parameters. [requestId] and [appId] are fresh per call.
  ///
  /// `r` and `enableMultiDeviceOnMultiType` are each sent twice, which is why
  /// the values are lists — dio serialises a `List` as a repeated key.
  static Map<String, Object> devices({
    required String userId,
    required String requestId,
    required String appId,
  }) => {
    'r': [requestId, requestId],
    'enableMultiDeviceOnMultiType': const ['true', 'true'],
    'userid': userId,
    'appid': appId,
    'channel': _zeppChannel,
    'country': 'US',
    'cv': _clientVersion,
    'device': 'android_32',
    'device_type': 'android_phone',
    'enableMultiDevice': 'true',
    'lang': 'en_US',
    'timezone': 'Europe/London',
    'v': '2.0',
  };
}
