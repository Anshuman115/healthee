/// Signing in with an identity, and what each step is allowed to store.
///
/// The negative assertions are the load-bearing ones, the same way
/// `server_session_test.dart`'s are. The state this must never produce is a
/// phone that believes it is signed in while holding a credential the server
/// never issued — and the state it must never destroy is a proven identity,
/// thrown away to tidy up after a later step failed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_probe.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/data/auth/device_token_client.dart';
import 'package:healthee/data/auth/identity_store.dart';

import '../pairing/_pairing_fakes.dart';
import '_identity_fakes.dart';
import '_signin_fakes.dart';

const String _url = 'https://healthee.example.com';
const String _minted = 'device-token-from-the-server-xyz';

/// The failure a sign-in threw, or null when it succeeded.
Future<ServerSignInFailure?> _failureOf(Future<void> Function() run) async {
  try {
    await run();
    return null;
  } on ServerSignInException catch (error) {
    return error.failure;
  }
}

/// A repository wired to a scripted identity provider and a scripted server.
ServerSessionRepository _repository(
  FakeSecretStore store,
  ScriptedAuth auth,
  ScriptedServer server,
) {
  return ServerSessionRepository(
    credentials: Credentials(store),
    probe: probeWith(server),
    identity: identityWith(auth, store),
    devices: DeviceTokenClient(
      DeviceTokenClient.dioFor()..httpClientAdapter = server,
    ),
  );
}

void main() {
  group('what reaches the keystore is what the SERVER issued', () {
    test('the stored credential is the minted device token', () async {
      final store = FakeSecretStore();
      final server = ScriptedServer(
        reply: const ServerReply(200, body: '{"device_token":"$_minted","id":"x"}'),
      );

      await _repository(store, ScriptedAuth(), server).signIn(
        url: _url,
        email: 'owner@example.com',
        password: 'correct horse',
      );

      // **Not the password, and not the JWT.** The password is never persisted
      // by anything; the JWT lives about an hour and is `gotrue`'s to refresh.
      // What this phone keeps is the long-lived credential `/ingest/*` takes.
      expect(await Credentials(store).apiToken(), _minted);
      expect(await Credentials(store).apiBaseUrl(), _url);
      expect(store.values.values.join('\n'), isNot(contains('correct horse')));
    });

    test('the Supabase session is persisted, and the password is not', () async {
      final store = FakeSecretStore();
      final server = ScriptedServer(
        reply: const ServerReply(200, body: '{"device_token":"$_minted","id":"x"}'),
      );

      await _repository(store, ScriptedAuth(), server).signIn(
        url: _url,
        email: 'owner@example.com',
        password: 'correct horse',
      );

      final session = store.values[kIdentitySessionKey];
      expect(session, isNotNull, reason: 'a restart must not sign the owner out');
      expect(session, contains(kRefreshToken));
      expect(session, isNot(contains('correct horse')));
    });

    test('THE SERVER IS ASKED WITH THE JWT, NOT WITH A DEVICE TOKEN', () async {
      // `/api/*` takes no device token, so probing with one would report every
      // correct sign-in as refused. The mint is the only call that may present
      // the JWT afterwards, and it does.
      final store = FakeSecretStore();
      final server = ScriptedServer(
        reply: const ServerReply(200, body: '{"device_token":"$_minted","id":"x"}'),
      );

      await _repository(store, ScriptedAuth(), server).signIn(
        url: _url,
        email: 'owner@example.com',
        password: 'correct horse',
      );

      expect(server.sent, hasLength(2));
      final verify = server.sent.first;
      expect(verify.uri.path, kVerifyPath);
      expect(verify.headers['Authorization'], 'Bearer $kAccessToken');

      final mint = server.sent.last;
      expect(mint.uri.path, kDevicePath);
      expect(mint.headers['Authorization'], 'Bearer $kAccessToken');
    });
  });

  group('a step that fails stores nothing after it', () {
    test('a refused password never reaches the server at all', () async {
      final store = FakeSecretStore();
      final server = ScriptedServer();

      final failure = await _failureOf(
        () => _repository(
          store,
          ScriptedAuth(status: 400, reply: const <String, Object?>{
            'error_code': 'invalid_credentials',
            'msg': 'Invalid login credentials',
          }),
          server,
        ).signIn(url: _url, email: 'owner@example.com', password: 'wrong'),
      );

      expect(failure, isA<IdentityRefused>());
      // The whole point of doing the identity first: a typo is answered without
      // the owner's server ever being told there was an attempt.
      expect(server.sent, isEmpty);
      expect(store.values, isEmpty);
    });

    test('AN UNINVITED EMAIL IS NOT A WRONG PASSWORD', () async {
      // The signup gate answers 403 to a verified identity this deployment has
      // not been told to accept. Reported as a refused credential, the owner
      // would go and reset a password that was already correct.
      final store = FakeSecretStore();
      final failure = await _failureOf(
        () => _repository(
          store,
          ScriptedAuth(),
          ScriptedServer(reply: const ServerReply(403)),
        ).signIn(url: _url, email: 'owner@example.com', password: 'right'),
      );

      expect(failure, isA<ServerRefusedThisAccount>());
      expect(await Credentials(store).apiToken(), isNull);
    });

    test('a failed mint leaves the identity SIGNED IN, and stores no session', () async {
      // Correct and recoverable: pressing sign in again re-uses the live
      // identity and retries the mint. Signing the owner back out to "clean up"
      // would throw away a proven credential to make a failure tidier.
      final store = FakeSecretStore();
      final mintFails = ScriptedServer(
        replies: <ServerReply>[
          const ServerReply(200, body: '{"premium":false}'),
          const ServerReply(500),
        ],
      );

      final failure = await _failureOf(
        () => _repository(store, ScriptedAuth(), mintFails).signIn(
          url: _url,
          email: 'owner@example.com',
          password: 'right',
        ),
      );

      expect(failure, isA<ServerAnsweredUnexpectedly>());
      expect(await Credentials(store).apiToken(), isNull);
      expect(
        store.values[kIdentitySessionKey],
        isNotNull,
        reason: 'the identity was proved; only the mint failed',
      );
    });

    test('the device cap comes through in the SERVER’s own words', () async {
      const said =
          'This account already has 10 device tokens. Revoke one you no longer '
          'use, then try again.';
      final failure = await _failureOf(
        () => _repository(
          FakeSecretStore(),
          ScriptedAuth(),
          ScriptedServer(
            replies: <ServerReply>[
              const ServerReply(200, body: '{"premium":false}'),
              const ServerReply(409, body: '{"detail":"$said"}'),
            ],
          ),
        ).signIn(url: _url, email: 'owner@example.com', password: 'right'),
      );

      expect(failure, isA<DeviceTokenCapReached>());
      // The server owns the number; a client composing its own sentence would be
      // a second definition of a limit it does not set.
      expect(failure!.remedy, said);
    });
  });

  group('a build with no identity provider', () {
    test('says so rather than offering a form that cannot work', () async {
      final failure = await _failureOf(
        () => repositoryWith(FakeSecretStore(), ScriptedServer()).signIn(
          url: _url,
          email: 'owner@example.com',
          password: 'right',
        ),
      );

      expect(failure, isA<IdentityNotConfigured>());
      expect(failure!.remedy, contains('strap still pairs'));
    });
  });
}
