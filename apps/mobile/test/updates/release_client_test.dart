/// What the release check sends to GitHub, and what it must never send.
///
/// The load-bearing test is the negative one. This client asks a third party a
/// question that needs no identity, and the app's own client attaches the owner's
/// credential to every request it makes. Reusing that one here would have sent
/// somebody's access token to `api.github.com` on every app open — quietly, and
/// forever.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/updates/release_client.dart';

import '../signin/_signin_fakes.dart';

/// The release payload GitHub returns, trimmed to what is read.
const String _body = '''
{"tag_name":"v0.2.0","draft":false,"prerelease":false,
 "body":"<!-- versionCode: 7 -->\\n\\nnotes",
 "assets":[{"name":"healthee-v0.2.0.apk","size":72189602,
   "browser_download_url":"https://github.com/afkcodes/healthee/releases/download/v0.2.0/healthee-v0.2.0.apk"}]}
''';

ReleaseClient _clientWith(ScriptedServer server) {
  final dio = ReleaseClient.dioFor()..httpClientAdapter = server;
  return ReleaseClient(dio);
}

void main() {
  test('NO AUTHORIZATION HEADER EVER REACHES GITHUB', () async {
    final server = ScriptedServer(reply: const ServerReply(200, body: _body));

    await _clientWith(server).latest();

    expect(server.sent, hasLength(1));
    final headers = server.sent.single.headers;
    expect(headers.containsKey('Authorization'), isFalse);
    expect(headers.containsKey('authorization'), isFalse);
    // Nor anywhere else it could be smuggled: not the query, not a cookie.
    expect(server.sent.single.uri.query, isEmpty);
    expect(headers.containsKey('Cookie'), isFalse);
  });

  test('it asks the releases endpoint of the published repo, pinned', () async {
    final server = ScriptedServer(reply: const ServerReply(200, body: _body));

    await _clientWith(server).latest();

    final request = server.sent.single;
    expect(request.uri.toString(), kLatestReleaseUrl);
    // The API version pin: without it the shape is whatever their default is.
    expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');
  });

  test('a 200 with a usable release is read back', () async {
    final release = await _clientWith(
      ScriptedServer(reply: const ServerReply(200, body: _body)),
    ).latest();

    expect(release, isNotNull);
    expect(release!.versionCode, 7);
    expect(release.downloadUrl, endsWith('.apk'));
  });

  group('every unhappy answer is null — "could not ask", not "up to date"', () {
    test('404: the repository has published nothing yet', () async {
      final release = await _clientWith(
        ScriptedServer(reply: const ServerReply(404, body: '{"message":"Not Found"}')),
      ).latest();

      expect(release, isNull);
    });

    test('403: the anonymous rate limit', () async {
      expect(
        await _clientWith(
          ScriptedServer(reply: const ServerReply(403)),
        ).latest(),
        isNull,
      );
    });

    test('200 with HTML — a captive portal answering for GitHub', () async {
      // The failure that looks like success. A hotel portal returns 200 and a
      // login page; parsed loosely that becomes "no update" forever.
      expect(
        await _clientWith(
          ScriptedServer(
            reply: const ServerReply(200, body: '<!doctype html><title>Sign in'),
          ),
        ).latest(),
        isNull,
      );
    });

    test('a redirect is not followed', () async {
      expect(
        await _clientWith(ScriptedServer(reply: const ServerReply(302))).latest(),
        isNull,
      );
    });
  });
}
