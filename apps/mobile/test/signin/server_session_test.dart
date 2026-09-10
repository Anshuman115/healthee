/// What is stored, when, and what is emphatically not.
///
/// The load-bearing assertions here are the negative ones. A token that reaches
/// the keystore without the server having accepted it is the bug this whole work
/// package exists to end: the app then believes it is signed in, every `/api/*`
/// call 401s, and Today renders the server's half as withheld — which reads as
/// "your data is missing" rather than "your token is wrong".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_probe.dart';
import 'package:healthee/data/api/signin_failure.dart';

import '../pairing/_pairing_fakes.dart';
import '_signin_fakes.dart';

const String _url = 'https://healthee.example.com';

/// The failure a sign-in throws, or null when it succeeded.
Future<ServerSignInFailure?> _failureOf(Future<void> Function() run) async {
  try {
    await run();
    return null;
  } on ServerSignInException catch (error) {
    return error.failure;
  }
}

void main() {
  group('200 stores the session, and only 200 does', () {
    test('an accepted token reaches the keystore with its server', () async {
      final store = FakeSecretStore();
      final repository = repositoryWith(store, ScriptedServer());

      await repository.signInWithToken(url: _url, token: kSentinelToken);

      expect(await Credentials(store).apiToken(), kSentinelToken);
      expect(await Credentials(store).apiBaseUrl(), _url);
    });

    test(
      'the check goes to /api/entitlement with the token as a Bearer',
      () async {
        final server = ScriptedServer();
        await repositoryWith(
          FakeSecretStore(),
          server,
        ).signInWithToken(url: _url, token: kSentinelToken);

        expect(server.sent, hasLength(1));
        final request = server.sent.single;
        expect(
          request.uri.toString(),
          'https://healthee.example.com$kVerifyPath',
        );
        expect(request.headers['Authorization'], 'Bearer $kSentinelToken');
        // Never in the URL: a query string lands in access logs and proxies.
        expect(request.uri.query, isEmpty);
        expect(request.uri.toString(), isNot(contains(kSentinelToken)));
      },
    );

    test('signing in reports the session afterwards', () async {
      final store = FakeSecretStore();
      final repository = repositoryWith(store, ScriptedServer());

      expect((await repository.status()).signedIn, isFalse);
      await repository.signInWithToken(url: _url, token: kSentinelToken);

      final status = await repository.status();
      expect(status.signedIn, isTrue);
      expect(status.baseUrl, _url);
      expect(status.host, 'healthee.example.com');
    });
  });

  group('401 stores NOTHING, and is named a refusal', () {
    test('a refused token is not written, at all', () async {
      final store = FakeSecretStore();
      final repository = repositoryWith(
        store,
        ScriptedServer(
          reply: const ServerReply(401, body: '{"detail":"nope"}'),
        ),
      );

      final failure = await _failureOf(
        () => repository.signInWithToken(url: _url, token: kSentinelToken),
      );

      expect(failure, isA<TokenRefused>());
      expect(store.values, isEmpty);
      expect((await repository.status()).signedIn, isFalse);
    });

    test('403 IS A DIFFERENT ANSWER, AND SAYS SO', () async {
      // **These used to be one case, and collapsing them costs an evening.**
      // 401 says the credential is not one this server accepts. 403 says it read
      // the credential, knows exactly whose it is, and will not serve that
      // account — an uninvited signup, or a suspension. Reported as a refused
      // credential, an owner whose email was simply not on the allowlist goes
      // and resets a password that was never wrong.
      final store = FakeSecretStore();
      final failure = await _failureOf(
        () => repositoryWith(
          store,
          ScriptedServer(reply: const ServerReply(403)),
        ).signInWithToken(url: _url, token: kSentinelToken),
      );

      expect(failure, isA<ServerRefusedThisAccount>());
      // The remedy is the point of the split, so it is what is asserted: it
      // sends the owner to the operator, and it says outright that the
      // credential was not the problem — which is the sentence that stops them
      // resetting a password that was already correct.
      expect(failure!.remedy, contains('Ask whoever runs it'));
      expect(failure.remedy, contains('nothing is wrong with your email or password'));
      expect(store.values, isEmpty);
    });

    test(
      'a refusal says the connection was fine — and offers no retry',
      () async {
        final failure = await _failureOf(
          () => repositoryWith(
            FakeSecretStore(),
            ScriptedServer(reply: const ServerReply(401)),
          ).signInWithToken(url: _url, token: kSentinelToken),
        );

        expect(failure!.headline, 'That token was refused by the server');
        expect(failure.remedy, contains('the connection itself is fine'));
        expect(failure.canRetry, isFalse);
      },
    );

    test('an existing session is NOT replaced by a failed sign-in', () async {
      final store = FakeSecretStore();
      await repositoryWith(
        store,
        ScriptedServer(),
      ).signInWithToken(url: _url, token: kSentinelToken);

      await _failureOf(
        () => repositoryWith(
          store,
          ScriptedServer(reply: const ServerReply(401)),
        ).signInWithToken(url: 'https://other.example.com', token: 'WRONG-TOKEN-9a3'),
      );

      expect(await Credentials(store).apiToken(), kSentinelToken);
      expect(await Credentials(store).apiBaseUrl(), _url);
    });
  });

  group('something else answered — neither a yes nor a no', () {
    test('a 500 is not called a refusal', () async {
      final failure = await _failureOf(
        () => repositoryWith(
          FakeSecretStore(),
          ScriptedServer(reply: const ServerReply(500)),
        ).signInWithToken(url: _url, token: kSentinelToken),
      );

      expect(failure, isA<ServerAnsweredUnexpectedly>());
      expect(failure!.remedy, contains('a server error'));
    });

    test('a login page answering 200 with HTML is not a sign-in', () async {
      final store = FakeSecretStore();
      final failure = await _failureOf(
        () => repositoryWith(
          store,
          ScriptedServer(
            reply: const ServerReply(200, body: '<!doctype html><title>Log in'),
          ),
        ).signInWithToken(url: _url, token: kSentinelToken),
      );

      expect(failure, isA<ServerAnsweredUnexpectedly>());
      expect(store.values, isEmpty);
    });

    test('a redirect is refused rather than followed with the token', () async {
      final failure = await _failureOf(
        () => repositoryWith(
          FakeSecretStore(),
          ScriptedServer(reply: const ServerReply(302)),
        ).signInWithToken(url: _url, token: kSentinelToken),
      );

      expect(
        failure!.remedy,
        contains('will not follow while carrying a token'),
      );
    });
  });

  group(
    'a pasted token carries whitespace, and that must not read as wrong',
    () {
      test('surrounding whitespace and a newline still sign in', () async {
        final store = FakeSecretStore();
        final server = ScriptedServer();

        await repositoryWith(
          store,
          server,
        ).signInWithToken(url: _url, token: '  $kSentinelToken\n');

        // Trimmed before it was sent…
        expect(
          server.sent.single.headers['Authorization'],
          'Bearer $kSentinelToken',
        );
        // …and before it was stored, so the next request matches too.
        expect(await Credentials(store).apiToken(), kSentinelToken);
      });

      test('the address is trimmed as well', () async {
        final store = FakeSecretStore();
        await repositoryWith(
          store,
          ScriptedServer(),
        ).signInWithToken(url: '  $_url  ', token: kSentinelToken);

        expect(await Credentials(store).apiBaseUrl(), _url);
      });

      test('whitespace alone is "no token", not a refusal', () async {
        final store = FakeSecretStore();
        final server = ScriptedServer();
        final failure = await _failureOf(
          () => repositoryWith(store, server).signInWithToken(url: _url, token: ' \n '),
        );

        expect(failure, isA<MissingToken>());
        // Nothing was sent: an empty credential is not the server's question.
        expect(server.sent, isEmpty);
        expect(store.values, isEmpty);
      });
    },
  );

  group('cleartext is refused before a byte leaves', () {
    test('a remote http address never reaches the network', () async {
      final store = FakeSecretStore();
      final server = ScriptedServer();

      final failure = await _failureOf(
        () => repositoryWith(
          store,
          server,
        ).signInWithToken(url: 'http://healthee.example.com', token: kSentinelToken),
      );

      expect(failure, isA<CleartextServerUrl>());
      expect(server.sent, isEmpty, reason: 'the token must not go on the wire');
      expect(store.values, isEmpty);
    });

    test(
      'loopback over http is allowed, because it never leaves the device',
      () async {
        final store = FakeSecretStore();
        await repositoryWith(
          store,
          ScriptedServer(),
        ).signInWithToken(url: 'http://127.0.0.1:8765', token: kSentinelToken);

        expect(await Credentials(store).apiBaseUrl(), 'http://127.0.0.1:8765');
      },
    );
  });

  group('sign-out', () {
    test('clears the token AND the address from the keystore', () async {
      final store = FakeSecretStore();
      final repository = repositoryWith(store, ScriptedServer());
      await repository.signInWithToken(url: _url, token: kSentinelToken);

      await repository.signOut();

      expect(store.values.containsKey('helio_token'), isFalse);
      expect(store.values.containsKey('helio_base_url'), isFalse);
      expect(store.values.values, isNot(contains(kSentinelToken)));
      expect((await repository.status()).signedIn, isFalse);
    });

    test(
      'leaves the strap pairing alone — signing out is not unpairing',
      () async {
        final store = FakeSecretStore()
          ..values['strap_mac'] = 'DB:98:1F:80:4C:3D'
          ..values['strap_auth_key'] = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
        final repository = repositoryWith(store, ScriptedServer());
        await repository.signInWithToken(url: _url, token: kSentinelToken);

        await repository.signOut();

        expect(store.values['strap_mac'], 'DB:98:1F:80:4C:3D');
        expect(
          store.values['strap_auth_key'],
          'a1b2c3d4e5f60718293a4b5c6d7e8f90',
        );
      },
    );

    test('is idempotent — signing out twice is not an error', () async {
      final store = FakeSecretStore();
      final repository = repositoryWith(store, ScriptedServer());

      await repository.signOut();
      await repository.signOut();

      expect(await Credentials(store).serverSession(), isNull);
    });
  });
}
