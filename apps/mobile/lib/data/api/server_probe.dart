/// The one authenticated call that decides whether a token is real.
///
/// ## Why `GET /api/entitlement`
///
/// It has to be an endpoint that (a) requires the bearer token, (b) is cheap,
/// and (c) answers the same way for every owner. `/api/entitlement` is the only
/// one that is all three:
///
///  * `apps/server/.../api/routers/entitlement.py` reads one `subscription` row
///    and no samples — the lightest authenticated read on the API;
///  * its own docstring says it is **deliberately ungated** ("a locked-out owner
///    is exactly who needs to read it"), so a free or lapsed owner still gets
///    200 rather than 402, and a paywall could never be misread as a bad token;
///  * it is uncached, so a 200 means the server answered *now*.
///
/// **`/api/me` was the obvious candidate and is wrong.** `routers/auth.py` binds
/// it to `current_user` — Supabase JWT only, deliberately not the dual-auth
/// dependency — so it answers 401 to the shared token that is the only thing
/// that works today. Probing with it would report every correct token as refused.
///
/// `/api/today` would also authenticate, but it is ~20 KB of aggregate built
/// from a day of samples: a sign-in button should not cost the server a derive.
///
/// ## A refusal and a dead connection are different code paths, not two branches
///
/// This client gets its **own** dio with `validateStatus: (_) => true`, so a 401
/// is a *status code on a `Response`* and a dead network is the *only* thing
/// that throws. The distinction the owner sees is therefore structural: there is
/// no path on which a refusal can be reported as unreachable, because by the
/// time we have a status the `catch` is already behind us.
///
/// Redirects are **not followed**. A 3xx would otherwise re-send the
/// Authorization header to whatever host the `Location` names, which is a token
/// leak triggered by somebody else's nginx config. It is reported as an answer
/// this app did not expect, which is what it is.
///
/// ## Nothing here logs the token
///
/// No logging interceptor on this dio; `DioException` objects are never handed
/// to the logger (their `message` can quote the request); every line is built
/// from a host, an HTTP status and a [ServerSignInFailure.code] — all ours.
/// `test/signin/signin_secrecy_test.dart` is the proof.
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/server_url.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/data/api/transport_failure.dart';

/// The endpoint a sign-in is checked against. See the library docstring.
const String kVerifyPath = '/api/entitlement';

/// Asks a server whether it accepts a token.
class ServerProbe {
  /// [dio] must be configured by [ServerProbe.dioFor].
  const ServerProbe(this._dio);

  /// The dio this probe needs: no interceptors, no redirects, and every status
  /// inspected here rather than raised.
  static Dio dioFor({Duration timeout = Env.requestTimeout}) {
    return Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        followRedirects: false,
        // Parsed here, so a non-JSON reply is a named failure rather than an
        // unhandled FormatException inside dio's transformer.
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );
  }

  final Dio _dio;

  /// Returns normally iff [url] accepted [token]. Throws
  /// [ServerSignInException] with a named failure otherwise.
  ///
  /// [token] must already be trimmed; `ServerSessionRepository` owns that step
  /// so there is one place it happens.
  Future<void> verify({required ServerUrl url, required String token}) async {
    final Response<String> response;
    try {
      response = await _dio.getUri<String>(
        url.resolve(kVerifyPath),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
    } on DioException catch (error) {
      final failure = unreachableFailure(error, url.host);
      // The TYPE and our own code; never the exception object, never the header.
      AppLog.failure(
        'signin',
        '${url.host} did not answer (${error.type.name})',
        'transport failure while checking the server token',
      );
      throw ServerSignInException(failure);
    }
    _judge(response, url);
  }

  /// Turns a status code into a yes, a refusal, or an honest "that is not us".
  void _judge(Response<String> response, ServerUrl url) {
    final status = response.statusCode ?? 0;
    if (status == 401) {
      AppLog.info('signin', '${url.host} refused the token (HTTP $status)');
      throw ServerSignInException(TokenRefused(status));
    }
    // **403 is not 401, and collapsing them costs an evening.** 401 says the
    // credential is not one this server accepts. 403 says it read the credential,
    // knows exactly whose it is, and will not serve that account — an uninvited
    // signup or a suspension. Reported as a refused token, an owner whose email
    // was simply not on the allowlist would go and reset a correct password.
    if (status == 403) {
      AppLog.info('signin', '${url.host} knows this account and refused it');
      throw const ServerSignInException(ServerRefusedThisAccount());
    }
    if (status >= 200 && status < 300) {
      if (!_looksLikeJsonObject(response.data)) {
        throw _unexpected(url, status, 'a reply that is not a JSON object');
      }
      AppLog.info('signin', '${url.host} accepted the token');
      return;
    }
    throw _unexpected(url, status, _describe(status));
  }

  /// A cheap shape check, not a parse.
  ///
  /// The probe's question is "does this behave like the Healthee API", and a
  /// login page answering 200 with HTML is the failure worth catching. Parsing
  /// the entitlement payload properly belongs to whoever renders it; doing it
  /// here would put a second definition of that model in the sign-in path.
  static bool _looksLikeJsonObject(String? body) =>
      body != null && body.trimLeft().startsWith('{');

  static String _describe(int status) {
    if (status >= 300 && status < 400) {
      // Not followed, on purpose — see the library docstring.
      return 'a redirect, which Healthee will not follow while carrying a token';
    }
    if (status >= 500) {
      return 'a server error, so it may be the right address on a bad day';
    }
    return 'a reply the Healthee API does not give';
  }

  ServerSignInException _unexpected(ServerUrl url, int status, String detail) {
    AppLog.warning('signin', '${url.host} answered HTTP $status: $detail');
    return ServerSignInException(
      ServerAnsweredUnexpectedly(status: status, detail: detail),
    );
  }


}
