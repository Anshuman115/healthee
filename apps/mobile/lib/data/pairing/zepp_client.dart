/// The three Zepp calls, and the only place a Zepp password is handled.
///
/// ## The password never leaves the device except to Zepp
///
/// It goes into [signIn], into an AES block, into one HTTPS request to Zepp's
/// own login endpoint, and nowhere else. It is not sent to the Healthee API,
/// there is no server endpoint for it, and there is nothing to add one to — a
/// self-hosted product whose owner's account credential round-trips through a
/// server is not self-hosted in the sense that matters.
///
/// ## Nothing from this host is logged beyond a status code
///
/// This client gets its **own** dio, without the app's `ApiLogInterceptor`. That
/// is not an oversight to be tidied up later: the interceptor logs paths and
/// (behind a flag) bodies, and on this host the interesting values are a
/// `Location` header carrying an access token, a body carrying an app token, and
/// a body carrying the strap's auth key. The legacy Python had to reach into its
/// HTTP library and disable the logger *because the library printed the
/// url-encoded password by default* — same hazard, one language over.
///
/// So the rules here are structural rather than careful:
///
///  * no logging interceptor on this dio;
///  * `DioException` objects are never handed to the logger, because their
///    `toString` carries the request URI and often the response body;
///  * every log line is assembled from a step name, an HTTP status and a
///    [PairingFailure.code] — all three of which are ours, and none of which
///    come from a response.
///
/// `test/pairing/pairing_secrecy_test.dart` runs the whole flow with sentinel
/// secrets and fails if any of them reaches a log line.
library;

import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/pairing/pairing_exception.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/pairing/zepp_crypto.dart';
import 'package:healthee/data/pairing/zepp_device.dart';
import 'package:healthee/data/pairing/zepp_endpoints.dart';
import 'package:healthee/data/pairing/zepp_session.dart';

/// Talks to the Zepp account API. One instance per pairing attempt is fine.
class ZeppClient {
  /// [dio] must be configured by [ZeppClient.dioFor]; [random] is injectable so
  /// a test gets deterministic request ids.
  ZeppClient(this._dio, {Random? random}) : _random = random ?? Random.secure();

  /// The dio this client needs: no redirects, no throwing on status, no
  /// interceptors. Every status is inspected here rather than raised, so that
  /// each one maps to a NAMED failure instead of a generic exception.
  static Dio dioFor({Duration timeout = const Duration(seconds: 20)}) {
    return Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        // Step 1's answer IS the redirect. Following it would send the tokens to
        // an Amazon S3 page and hand us its HTML instead.
        followRedirects: false,
        // Bodies are parsed here, so a non-JSON reply is a named failure rather
        // than an unhandled FormatException inside dio's transformer.
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );
  }

  final Dio _dio;
  final Random _random;

  /// Steps 1 and 2: email + password in, an app token and user id out.
  Future<ZeppSession> signIn({
    required String email,
    required String password,
  }) async {
    final accessToken = await _requestAccessToken(email: email, password: password);
    return _exchangeForAppToken(accessToken);
  }

  /// Step 3: the account's bound devices, as usable pairings.
  ///
  /// Throws [NoBoundDevices] both when the list is empty and when every entry
  /// was unusable — from the owner's side those are the same sentence, and the
  /// log line distinguishes them for us.
  Future<List<ZeppDevice>> devices(ZeppSession session) async {
    final response = await _send(
      'the device list',
      () => _dio.getUri<String>(
        Uri.parse(ZeppUrls.devicesFor(session.userId)).replace(
          queryParameters: ZeppQuery.devices(
            userId: session.userId,
            requestId: _uuidV4(),
            appId: _appId(),
          ),
        ),
        options: Options(
          headers: ZeppHeaders.devices(
            appToken: session.appToken,
            requestId: _uuidV4(),
          ),
        ),
      ),
    );

    if (response.statusCode != 200) {
      throw _apiChanged('the device list', 'HTTP ${response.statusCode}');
    }

    final body = _decodeJson('the device list', response.data);
    final items = body['items'];
    if (items is! List) {
      throw _apiChanged('the device list', 'no items list in the reply');
    }

    final devices = <ZeppDevice>[];
    for (final item in items) {
      if (item is Map<String, Object?>) {
        final device = ZeppDevice.fromJson(item);
        if (device != null) {
          devices.add(device);
        }
      }
    }

    if (devices.isEmpty) {
      AppLog.warning(
        'pairing',
        'zepp returned ${items.length} device(s), none with a usable key',
      );
      throw const PairingException(NoBoundDevices());
    }
    AppLog.info('pairing', 'zepp returned ${devices.length} usable device(s)');
    return devices;
  }

  /// Step 1 — the encrypted credential exchange. Returns the `access` token.
  Future<String> _requestAccessToken({
    required String email,
    required String password,
  }) async {
    final payload = encryptZeppPayload(
      encodeForm(ZeppForms.tokens(email: email, password: password)),
      key: ZeppCipher.key,
      iv: ZeppCipher.iv,
    );

    final response = await _send(
      'the sign-in',
      () => _dio.postUri<String>(
        Uri.parse(ZeppUrls.tokens),
        data: payload,
        options: Options(headers: ZeppHeaders.tokens()),
      ),
    );

    final status = response.statusCode ?? 0;
    // A 4xx here is Zepp declining the credential, which is the one failure the
    // owner can actually fix by typing something different.
    if (status == 401 || status == 403 || status == 400) {
      AppLog.info('pairing', 'zepp declined the sign-in (HTTP $status)');
      throw const PairingException(WrongZeppCredentials());
    }
    if (status < 300 || status >= 400) {
      throw _apiChanged('the sign-in', 'HTTP $status, expected a redirect');
    }

    final location = response.headers.value('location');
    if (location == null || location.isEmpty) {
      throw _apiChanged('the sign-in', 'a redirect with no Location header');
    }

    final query = Uri.parse(location).queryParameters;
    final access = query['access'];
    if (access != null && access.isNotEmpty) {
      return access;
    }
    // A redirect that carries an error code instead of tokens is Zepp saying no.
    if (query.containsKey('error') || query.containsKey('error_code')) {
      AppLog.info('pairing', 'zepp redirect carried an error instead of tokens');
      throw const PairingException(WrongZeppCredentials());
    }
    throw _apiChanged('the sign-in', 'no access token in the redirect');
  }

  /// Step 2 — access token in, app token and user id out.
  Future<ZeppSession> _exchangeForAppToken(String accessToken) async {
    final response = await _send(
      'the login',
      () => _dio.postUri<String>(
        Uri.parse(ZeppUrls.login),
        data: ZeppForms.login(accessToken: accessToken, deviceId: _uuidV4()),
        options: Options(
          headers: ZeppHeaders.login(),
          contentType: Headers.formUrlEncodedContentType,
        ),
      ),
    );

    if (response.statusCode != 200) {
      throw _apiChanged('the login', 'HTTP ${response.statusCode}');
    }

    final tokenInfo = _decodeJson('the login', response.data)['token_info'];
    if (tokenInfo is! Map<String, Object?>) {
      throw _apiChanged('the login', 'no token_info in the reply');
    }
    final appToken = tokenInfo['app_token'];
    final userId = tokenInfo['user_id'];
    if (appToken is! String || appToken.isEmpty) {
      throw _apiChanged('the login', 'no app_token in the reply');
    }
    if (userId is! String || userId.isEmpty) {
      throw _apiChanged('the login', 'no user_id in the reply');
    }

    AppLog.info('pairing', 'zepp sign-in complete');
    return ZeppSession(userId: userId, appToken: appToken);
  }

  /// Runs one request, turning a transport failure into [NoNetwork].
  ///
  /// The `DioException` is caught, its TYPE is logged, and the object itself is
  /// dropped — see the library docstring. Nothing is swallowed: a named failure
  /// is thrown in its place and the caller must handle it.
  Future<Response<String>> _send(
    String step,
    Future<Response<String>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      AppLog.failure(
        'pairing',
        'zepp $step could not be sent (${error.type.name})',
        'transport failure on the Zepp host',
      );
      throw const PairingException(NoNetwork());
    }
  }

  Map<String, Object?> _decodeJson(String step, String? body) {
    if (body == null || body.isEmpty) {
      throw _apiChanged(step, 'an empty reply');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      // The body is not quoted into the failure: on this host it is the thing
      // that holds the tokens.
      throw _apiChanged(step, 'a reply that is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw _apiChanged(step, 'a reply that is not an object');
    }
    return decoded;
  }

  PairingException _apiChanged(String step, String detail) {
    AppLog.warning('pairing', 'zepp $step: $detail');
    return PairingException(ZeppApiChanged(step: step, detail: detail));
  }

  /// A version-4 UUID from a secure source. `uuid` is not worth a dependency for
  /// eleven lines, and these ids are request correlation, not entropy we rely on.
  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
        '-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// A random 64-bit decimal, matching the reference's `secrets.randbits(64)`.
  String _appId() {
    final high = BigInt.from(_random.nextInt(1 << 32));
    final low = BigInt.from(_random.nextInt(1 << 32));
    return ((high << 32) | low).toString();
  }
}
