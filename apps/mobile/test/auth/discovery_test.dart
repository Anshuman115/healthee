/// Sign-in asks the server who it trusts, BEFORE a password goes anywhere.
///
/// This is the change that lets one APK serve everybody: the identity provider
/// used to be compiled in, so a published build signed in against whoever made
/// it. Now the owner names a server and the server names its provider.
///
/// The assertions that matter are the three unhappy ones. Each has a different
/// remedy — configure the server, update the server, check the connection — and
/// reporting any of them as a credential problem would send the owner to change a
/// password that was never wrong.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/data/auth/auth_config.dart';
import 'package:healthee/data/auth/auth_config_client.dart';
import 'package:healthee/data/auth/device_token_client.dart';
import 'package:healthee/data/auth/identity_providers.dart';

import '../pairing/_pairing_fakes.dart';
import '../signin/_identity_fakes.dart';
import '../signin/_signin_fakes.dart';

const String _url = 'https://healthee.example.com';
const String _minted = 'device-token-from-the-server-xyz';

const String _configured = '''
{"supabase_url":"https://abcd.supabase.co",
 "supabase_anon_key":"anon-key-published-on-purpose"}
''';

/// A repository whose auth-config lookup is scripted independently of the server.
ServerSessionRepository _repository(
  FakeSecretStore store,
  ScriptedServer server,
  ScriptedServer authConfig,
) {
  return ServerSessionRepository(
    credentials: Credentials(store),
    probe: probeWith(server),
    identity: identityWith(ScriptedAuth(), store),
    devices: DeviceTokenClient(DeviceTokenClient.dioFor()..httpClientAdapter = server),
    authConfigs: AuthConfigClient(
      AuthConfigClient.dioFor()..httpClientAdapter = authConfig,
    ),
  );
}

Future<ServerSignInFailure?> _failureOf(Future<void> Function() run) async {
  try {
    await run();
    return null;
  } on ServerSignInException catch (error) {
    return error.failure;
  }
}

void main() {
  test('A DISCOVERED PROVIDER IS REMEMBERED, so a cold start needs no network', () async {
    final store = FakeSecretStore();
    final repository = _repository(
      store,
      ScriptedServer(reply: const ServerReply(200, body: '{"device_token":"$_minted","id":"x"}')),
      ScriptedServer(reply: const ServerReply(200, body: _configured)),
    );

    await repository.signIn(url: _url, email: 'owner@example.com', password: 'pw');

    final stored = await Credentials(store).authConfig();
    expect(stored, isNotNull);
    expect(stored!.supabaseUrl, 'https://abcd.supabase.co');
  });

  test('the server is asked BEFORE the password is presented', () async {
    final auth = ScriptedServer(reply: const ServerReply(200, body: _configured));
    await _failureOf(
      () => _repository(FakeSecretStore(), ScriptedServer(), auth).signIn(
        url: _url,
        email: 'owner@example.com',
        password: 'pw',
      ),
    );

    expect(auth.sent, isNotEmpty, reason: 'discovery never happened');
    expect(auth.sent.first.uri.path, '/api/auth-config');
  });

  group('THREE WAYS IT IS NOT A SIGN-IN, AND THREE DIFFERENT REMEDIES', () {
    Future<ServerSignInFailure?> failingWith(ServerReply reply) async {
      final store = FakeSecretStore();
      return _failureOf(
        () => _repository(store, ScriptedServer(), ScriptedServer(reply: reply)).signIn(
          url: _url,
          email: 'owner@example.com',
          password: 'pw',
        ),
      );
    }

    test('the server has no provider → configure IT, not your password', () async {
      final failure = await failingWith(
        const ServerReply(200, body: '{"supabase_url":null,"supabase_anon_key":null}'),
      );

      expect(failure, isA<ServerHasNoIdentityProvider>());
      expect(failure!.remedy, contains('Whoever runs it'));
      // The sentence that stops the owner retyping a correct password.
      expect(failure.remedy, contains('the address is right'));
    });

    test('the server is too old → UPDATE it, which is a different fix', () async {
      final failure = await failingWith(const ServerReply(404));

      expect(failure, isA<ServerTooOldForSignIn>());
      expect(failure!.remedy, contains('needs to update it'));
      expect(failure.remedy, contains('Nothing about your details is wrong'));
    });

    test('unreachable is a connection problem and says so', () async {
      final failure = await failingWith(const ServerReply(500));

      expect(failure, isA<ServerUnreachable>());
      expect(failure!.remedy, contains('connection problem'));
    });
  });

  test('NOTHING IS STORED when discovery fails', () async {
    // The rule the whole sign-in path follows: a step that did not land writes
    // nothing. A remembered provider from a server that cannot serve one would
    // point the NEXT sign-in at it.
    final store = FakeSecretStore();
    await _failureOf(
      () => _repository(store, ScriptedServer(), ScriptedServer(reply: const ServerReply(404)))
          .signIn(url: _url, email: 'owner@example.com', password: 'pw'),
    );

    expect(await Credentials(store).authConfig(), isNull);
    expect(store.values.containsKey('helio_token'), isFalse);
  });

  group('WHICH PROVIDER WINS, and why the order is the feature', () {
    // Extracted from a closure precisely so this can be asserted: a mutation
    // swapping the two survived while the ordering was inline, which is the
    // shape of gate that protects nothing.

    test('the DISCOVERED provider is preferred over the compiled-in one', () async {
      // Without this, a published APK signs in against whoever built it — the
      // whole thing auth-config exists to end.
      final store = FakeSecretStore();
      await Credentials(store).setAuthConfig(
        const AuthConfig(
          supabaseUrl: 'https://from-the-server.supabase.co',
          anonKey: 'server-anon-key',
        ),
      );

      final resolved = await resolveAuthConfig(Credentials(store));

      expect(resolved!.supabaseUrl, 'https://from-the-server.supabase.co');
      expect(resolved.anonKey, 'server-anon-key');
    });

    test('with nothing stored it falls back to the build, or to nothing', () async {
      // A test build carries no dart-defines, so this is null here — and null is
      // not a broken build, just one that has not been told yet.
      final resolved = await resolveAuthConfig(Credentials(FakeSecretStore()));

      expect(resolved, isNull);
    });

    test('and forgetting the session forgets the provider with it', () async {
      // It belongs to the SERVER. Left behind, it would point the next sign-in —
      // possibly at a different address — at the previous server's project.
      final store = FakeSecretStore();
      final credentials = Credentials(store);
      await credentials.setAuthConfig(
        const AuthConfig(supabaseUrl: 'https://old.supabase.co', anonKey: 'k'),
      );

      await credentials.forgetServerSession();

      expect(await credentials.authConfig(), isNull);
    });
  });
}
