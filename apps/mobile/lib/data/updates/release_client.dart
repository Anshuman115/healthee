/// Asks GitHub what the latest release is. Nothing else, and with nothing of ours.
///
/// ## ⛔ This client carries NO healthee credential, and that is structural
///
/// It is built here rather than taken from `apiClientProvider`, which is the whole
/// point: that client has `ServerSessionInterceptor` on it, so every request it
/// makes carries the owner's access token or device token. Pointing it at
/// `api.github.com` would send this person's credential to a third party on a
/// schedule, to ask a question that needs no identity at all.
///
/// A bare [Dio] cannot do that by construction. `signin_secrecy_test.dart` makes
/// the same argument about a token with no consumer; this is the version where
/// the consumer would have been somebody else's server.
///
/// ## Unauthenticated, because the repository is public
///
/// No token is sent, so the rate limit is the anonymous one (60/hour/IP) — far
/// more than a check-on-open needs. A token would have to ship inside the APK,
/// where anybody can read it out of a zip, and a GitHub token that can read
/// releases can read the source.
///
/// ## Every failure is "we could not ask", never "you are up to date"
///
/// A rate limit, an offline phone, a 404 from a repo with no releases yet: none of
/// them is evidence about the version. Reporting any of them as "no update" would
/// be the app telling the owner something it does not know, which is the one thing
/// this product refuses to do.
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/updates/app_release.dart';

/// The repository releases are published from.
const String kReleasesRepo = 'afkcodes/healthee';

/// Where the latest published release is described.
const String kLatestReleaseUrl =
    'https://api.github.com/repos/$kReleasesRepo/releases/latest';

/// How long GitHub is given to answer. Short: this is a background courtesy.
const Duration kReleaseCheckTimeout = Duration(seconds: 10);

/// Reads the latest published release, or null when it cannot be established.
class ReleaseClient {
  /// [dio] must be configured by [ReleaseClient.dioFor] — see the library doc.
  const ReleaseClient(this._dio);

  /// A bare client: no base URL, no interceptors, and so no credential.
  static Dio dioFor({Duration timeout = kReleaseCheckTimeout}) => Dio(
    BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      // A redirect carrying our request somewhere unnamed is not something to
      // follow silently, even without a credential on it.
      followRedirects: false,
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: const <String, String>{
        // GitHub's documented version pin. Without it the response shape is
        // whatever their default is that month.
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );

  final Dio _dio;

  /// Releases the underlying connection pool.
  ///
  /// Not ceremony: this client is built per check rather than kept alive, so a
  /// pool left open is one socket per check for the life of the process.
  void close() => _dio.close();

  /// The latest release, or null when this app cannot establish one.
  ///
  /// Null covers every unhappy path on purpose — offline, rate-limited, no
  /// releases yet, a release with no APK, a body we cannot parse. The caller
  /// reports "we could not check", and the difference between the causes belongs
  /// in the log rather than on a screen: none of them changes what the owner can
  /// do about it.
  Future<AppRelease?> latest() async {
    final Response<Object?> response;
    try {
      response = await _dio.getUri<Object?>(Uri.parse(kLatestReleaseUrl));
    } on DioException catch (error) {
      // The type, never the body: a GitHub error body is not secret, but a log
      // line that quotes a response is a habit that ends badly elsewhere.
      AppLog.info('updates', 'the release check could not reach GitHub (${error.type})');
      return null;
    }
    final status = response.statusCode ?? 0;
    if (status != 200) {
      // 404 is a repository with no published release yet, 403 is the anonymous
      // rate limit. Both are "we could not ask", and neither is an error worth
      // showing somebody who did not ask for an update check.
      AppLog.info('updates', 'the release check was answered $status');
      return null;
    }
    final body = response.data;
    if (body is! Map<String, Object?>) {
      AppLog.info('updates', 'the release check got a body this app cannot read');
      return null;
    }
    return AppRelease.fromJson(body);
  }
}
