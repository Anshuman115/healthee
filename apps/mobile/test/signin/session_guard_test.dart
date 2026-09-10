/// A 401 ends the session instead of being replayed forever (auth audit C4).
///
/// What this closes: `Credentials.forgetServerSession` had exactly one caller,
/// the sign-out button. A 401 dropped the affected cache rows, rendered "Sign in
/// to your server to use this feature", suppressed the retry and reported a push
/// failure — while `ServerSessionStatus.signedIn` went on returning true. So a
/// revoked or expired credential left the app believing it was signed in, serving
/// 401s to every screen, and re-sending the dead credential on every screen load
/// and every background sync, with nothing ever prompting a re-authentication.
///
/// Revocation would have shipped and not visibly worked, which is why this ships
/// with it rather than after it.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/interceptors.dart';

import '_signin_fakes.dart';

void main() {
  late ScriptedServer server;
  late int rejections;
  late Dio dio;

  setUp(() {
    server = ScriptedServer();
    rejections = 0;
    dio = Dio(BaseOptions(baseUrl: 'https://healthee.example.com'))
      ..httpClientAdapter = server
      ..interceptors.add(SessionGuardInterceptor(() => rejections++));
  });

  /// Runs [call] and swallows the DioException a non-2xx raises.
  Future<void> attempt(Future<void> Function() call) async {
    try {
      await call();
    } on DioException {
      // The guard observes; it does not absorb. The caller still sees the error.
    }
  }

  test('a 401 on /api/* ends the session, once', () async {
    server.reply = const ServerReply(401);
    await attempt(() => dio.get<Object?>('/api/today'));
    expect(rejections, 1);
  });

  test('403 DOES NOT — it is an answer, not a dead credential', () async {
    // The server knows exactly whose credential this is and will not serve that
    // account: a suspension, or a paywall. Signing the owner out over it would
    // replace an accurate message with a login screen that changes nothing.
    server.reply = const ServerReply(403);
    await attempt(() => dio.get<Object?>('/api/today'));
    expect(rejections, isZero);
  });

  test('A 401 ON /ingest/* DOES NOT SIGN ANYONE OUT', () async {
    // A push runs headless in a background isolate: there is nobody to prompt,
    // the device token is a separate credential with its own lifetime, and
    // revoking one phone's ingest token must not sign the owner out of the app
    // on that phone before they can see why.
    server.reply = const ServerReply(401);
    await attempt(
      () => dio.post<Object?>('/ingest/helio', data: <String, Object?>{}),
    );
    expect(rejections, isZero);
  });

  test('a 500 is a server fault, not a credential one', () async {
    server.reply = const ServerReply(500);
    await attempt(() => dio.get<Object?>('/api/today'));
    expect(rejections, isZero);
  });

  test('a dead network is not a rejection either', () async {
    server.failWith = hostNotFound('healthee.example.com');
    await attempt(() => dio.get<Object?>('/api/today'));
    expect(rejections, isZero);
  });

  test('the error still reaches the caller — the guard only observes', () async {
    server.reply = const ServerReply(401);
    await expectLater(
      dio.get<Object?>('/api/today'),
      throwsA(isA<DioException>()),
    );
    expect(rejections, 1);
  });
}
