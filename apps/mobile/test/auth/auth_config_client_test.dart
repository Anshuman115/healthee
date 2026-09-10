/// What the app concludes from each answer a server can give.
///
/// The four results are the point. "This server has no sign-in configured" and
/// "we could not reach it" send the owner to completely different places, and a
/// nullable would make them the same thing. So would an exception.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/server_url.dart';
import 'package:healthee/data/auth/auth_config.dart';
import 'package:healthee/data/auth/auth_config_client.dart';

import '../signin/_signin_fakes.dart';

final ServerUrl _url = ServerUrl.parse('https://healthee.example.com');

const String _configured = '''
{"supabase_url":"https://abcd.supabase.co",
 "supabase_anon_key":"anon-key-published-on-purpose"}
''';

AuthConfigClient _clientWith(ScriptedServer server) =>
    AuthConfigClient(AuthConfigClient.dioFor()..httpClientAdapter = server);

Future<AuthConfigResult> _ask(ServerReply reply) =>
    _clientWith(ScriptedServer(reply: reply)).forServer(_url);

void main() {
  test('a configured server names its provider', () async {
    final result = await _ask(const ServerReply(200, body: _configured));

    expect(result, isA<AuthConfigFound>());
    final config = (result as AuthConfigFound).config;
    expect(config.supabaseUrl, 'https://abcd.supabase.co');
    expect(config.anonKey, 'anon-key-published-on-purpose');
    // `gotrue` is handed the auth endpoint, never the project root.
    expect(config.gotrueUrl, 'https://abcd.supabase.co/auth/v1');
  });

  test('it asks the documented path on the server it was given', () async {
    final server = ScriptedServer(reply: const ServerReply(200, body: _configured));

    await _clientWith(server).forServer(_url);

    expect(
      server.sent.single.uri.toString(),
      'https://healthee.example.com/api/auth-config',
    );
  });

  test('NO CREDENTIAL IS SENT — there is nothing to authenticate with yet', () async {
    // And more than that: whatever session is stored belongs to the PREVIOUS
    // server, and this call goes to an address the owner has just typed.
    final server = ScriptedServer(reply: const ServerReply(200, body: _configured));

    await _clientWith(server).forServer(_url);

    final headers = server.sent.single.headers;
    expect(headers.containsKey('Authorization'), isFalse);
    expect(headers.containsKey('authorization'), isFalse);
    expect(server.sent.single.uri.query, isEmpty);
  });

  group('the three ways it is NOT a provider, kept apart', () {
    test('200 with nulls → the server has none configured', () async {
      final result = await _ask(
        const ServerReply(
          200,
          body: '{"supabase_url":null,"supabase_anon_key":null}',
        ),
      );

      expect(result, isA<AuthConfigNone>());
    });

    test('404 → the server predates the endpoint, which is a DIFFERENT fix', () async {
      // Configure this one and it still will not work; update it and it might.
      // Collapsing the two would send the owner to the wrong place.
      expect(await _ask(const ServerReply(404)), isA<AuthConfigUnsupported>());
    });

    test('a dead connection says nothing about the server', () async {
      expect(await _ask(const ServerReply(500)), isA<AuthConfigUnreachable>());
    });
  });

  group('answers that are not answers', () {
    test('half a configuration is none of one', () async {
      // A URL with no key is a sign-in form that submits into a 400. The server
      // already refuses to serve half; this refuses to accept it either.
      final result = await _ask(
        const ServerReply(
          200,
          body: '{"supabase_url":"https://abcd.supabase.co","supabase_anon_key":""}',
        ),
      );

      expect(result, isA<AuthConfigNone>());
    });

    test('a captive portal answering 200 with HTML is unreachable', () async {
      final result = await _ask(
        const ServerReply(200, body: '<!doctype html><title>Sign in to wifi'),
      );

      expect(result, isA<AuthConfigUnreachable>());
      expect(result, isNot(isA<AuthConfigNone>()));
    });

    test('a redirect is not followed', () async {
      expect(await _ask(const ServerReply(302)), isA<AuthConfigUnreachable>());
    });
  });

  test('it round-trips through the keystore shape', () {
    const config = AuthConfig(
      supabaseUrl: 'https://abcd.supabase.co',
      anonKey: 'anon-key-published-on-purpose',
    );

    expect(AuthConfig.fromStored(config.toJson()), config);
  });
}
