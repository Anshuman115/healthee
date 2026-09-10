/// `POST /api/device` — asking the server for this phone's ingest credential.
///
/// Minting is authenticated with the **Supabase JWT**, never with a device token
/// and never with the transitional shared secret. `apps/server`'s own router says
/// why and enforces it: minting a device token is minting a long-lived
/// credential, so a shared secret accepted here would let anyone holding it forge
/// a permanent per-owner token that outlives the shared secret's removal.
///
/// ## It is returned once
///
/// The server stores only a SHA-256 hash, so a token that is not kept at the
/// moment it is minted is gone — the remedy is to mint another and revoke this
/// one, not to ask for it again. That is why this returns the raw value to
/// exactly one caller, `ServerSessionRepository.signIn`, which writes it to the
/// keystore in the same act.
///
/// ## Its own dio, like the probe's
///
/// No interceptors, so nothing attaches the app's stored session to a call whose
/// whole point is to establish one; no redirects, because this request carries a
/// bearer token and a 3xx would re-send it to whatever host the `Location` names;
/// and every status inspected rather than raised, so a refusal is a code path and
/// not a `catch`.
///
/// **Nothing here is logged.** Not the JWT, not the minted token. The host, the
/// status and this app's own failure codes, exactly as `server_probe.dart`.
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/server_url.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/data/api/transport_failure.dart';

/// Where a device token is minted.
const String kDevicePath = '/api/device';

/// Asks a server to mint this device's ingest token.
class DeviceTokenClient {
  /// [dio] must be configured by [DeviceTokenClient.dioFor].
  const DeviceTokenClient(this._dio);

  /// The dio this client needs. See the library docstring.
  static Dio dioFor({Duration timeout = Env.requestTimeout}) => Dio(
    BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      followRedirects: false,
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ),
  );

  final Dio _dio;

  /// Mints a device token for the owner [jwt] identifies. Throws
  /// [ServerSignInException] with a named failure.
  ///
  /// [label] is what the owner will see in their own list of devices when they
  /// come to revoke one. Without it they are choosing between two UUIDs.
  Future<String> mint({
    required ServerUrl url,
    required String jwt,
    required String? label,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.postUri<Object?>(
        url.resolve(kDevicePath),
        data: <String, Object?>{'label': ?label},
        options: Options(
          headers: {
            'Authorization': 'Bearer $jwt',
            'Accept': 'application/json',
          },
        ),
      );
    } on DioException catch (error) {
      AppLog.failure(
        'signin',
        '${url.host} did not answer the device-token request (${error.type.name})',
        'transport failure while minting the device token',
      );
      throw ServerSignInException(unreachableFailure(error, url.host));
    }
    return _read(response, url);
  }

  /// Turns the answer into a token, or into a named failure.
  String _read(Response<Object?> response, ServerUrl url) {
    final status = response.statusCode ?? 0;
    if (status == 403) {
      AppLog.info('signin', '${url.host} refused to mint for this account');
      throw const ServerSignInException(ServerRefusedThisAccount());
    }
    if (status == 409) {
      // The server's own sentence names the cap and says revoking frees a slot,
      // which is the whole remedy — so it is carried through rather than
      // replaced. The one place in this file that reads a response body, and it
      // reads a refusal written for a person.
      AppLog.info('signin', '${url.host} refused: this account is at its device cap');
      throw ServerSignInException(DeviceTokenCapReached(_detail(response.data)));
    }
    if (status == 401) {
      AppLog.info('signin', '${url.host} refused the sign-in token');
      throw const ServerSignInException(TokenRefused(401));
    }
    if (status < 200 || status >= 300) {
      AppLog.info('signin', '${url.host} answered $status to the device-token request');
      throw ServerSignInException(
        ServerAnsweredUnexpectedly(
          status: status,
          detail: 'the device-token request was not accepted',
        ),
      );
    }
    final data = response.data;
    if (data is! Map<String, Object?> || data['device_token'] is! String) {
      throw ServerSignInException(
        ServerAnsweredUnexpectedly(
          status: status,
          detail: 'a device-token reply this app could not read',
        ),
      );
    }
    return data['device_token']! as String;
  }

  /// The server's `detail` sentence, when it sent one.
  ///
  /// A refusal written for a person is more use than anything this client could
  /// compose, and `apps/server` writes these deliberately. Absent or the wrong
  /// shape, the failure supplies its own words rather than printing a fragment.
  static String? _detail(Object? data) {
    if (data is Map<String, Object?> && data['detail'] is String) {
      return data['detail']! as String;
    }
    return null;
  }
}
