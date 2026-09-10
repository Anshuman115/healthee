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
      // **The remedy names BOTH cases**, because the provider will not say which
      // — `invalid_credentials` covers a wrong password and an email it has
      // never seen, deliberately, so that the error cannot be used to ask
      // whether a stranger has an account. Advice for only one of the two is a
      // dead end for the other: an owner with no account retypes a correct
      // password until they give up.
      expect(failure!.remedy, contains('no account for that email yet'));
      expect(failure.remedy, contains('Create an account'));
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

  group('creating an account', () {
    test('it signs up, then does everything a sign-in does', () async {
      final store = FakeSecretStore();
      final auth = ScriptedAuth();
      final server = ScriptedServer(
        replies: const <ServerReply>[
          ServerReply(200, body: '{"premium":false}'),
          ServerReply(200, body: '{"device_token":"$_minted","id":"x"}'),
        ],
      );

      await _repository(store, auth, server).createAccount(
        url: _url,
        email: 'new@example.com',
        password: 'a long enough one',
      );

      // The signup endpoint, not the token one — the difference between the two
      // modes is exactly one call, and this is it.
      expect(auth.sent.single.url.path, endsWith('/signup'));
      // And everything after it is shared: the server was asked, a token was
      // minted, and only then was anything written down.
      expect(server.sent, hasLength(2));
      expect(await Credentials(store).apiToken(), _minted);
    });

    test('AN EMAIL THAT ALREADY HAS AN ACCOUNT IS ITS OWN ANSWER', () async {
      // The opposite mistake to signing in without one, and the opposite
      // remedy. Collapsed into "that did not work", the owner retries the
      // create that can never succeed instead of switching to sign in.
      final failure = await _failureOf(
        () => _repository(
          FakeSecretStore(),
          ScriptedAuth(
            status: 422,
            reply: const <String, Object?>{
              'error_code': 'user_already_exists',
              'msg': 'User already registered',
            },
          ),
          ScriptedServer(),
        ).createAccount(
          url: _url,
          email: 'owner@example.com',
          password: 'whatever',
        ),
      );

      expect(failure, isA<IdentityAlreadyExists>());
      expect(failure!.remedy, contains('Sign in instead'));
    });

    test('A PROJECT THAT CONFIRMS EMAILS IS NOT A FAILURE', () async {
      // Supabase returns a user and NO session when confirmation is on. The
      // account exists and the owner has a mail to open; reporting that as a
      // refusal would send them to reset a password that was just accepted.
      final store = FakeSecretStore();
      final failure = await _failureOf(
        () => _repository(
          store,
          // A signup response carrying no session at all.
          ScriptedAuth(reply: const <String, Object?>{'user': null}),
          ScriptedServer(),
        ).createAccount(
          url: _url,
          email: 'new@example.com',
          password: 'a long enough one',
        ),
      );

      expect(failure, isA<IdentityNeedsConfirmation>());
      expect(failure!.headline, contains('Confirm your email'));
      // Nothing stored: there is no session to mint against yet.
      expect(await Credentials(store).apiToken(), isNull);
    });

    test('A REASON THIS APP HAS NO CASE FOR IS NOT A WRONG PASSWORD', () async {
      // The defect this closes, exactly as it shipped: a project with email
      // confirmation on that cannot send the mail answers with a code this app
      // does not map, and the fallback told someone choosing a NEW password that
      // their password was wrong. There is nothing to match against on a signup.
      final failure = await _failureOf(
        () => _repository(
          FakeSecretStore(),
          ScriptedAuth(
            status: 422,
            reply: const <String, Object?>{
              'error_code': 'error_sending_confirmation_email',
              'msg': 'Error sending confirmation email',
            },
          ),
          ScriptedServer(),
        ).createAccount(
          url: _url,
          email: 'new@example.com',
          password: 'a long enough one',
        ),
      );

      expect(failure, isA<IdentityUnrecognised>());
      expect(failure, isNot(isA<IdentityRefused>()));
      expect(failure!.headline, 'That account could not be created');
      // It says the credentials were NOT the problem, and it names the code so
      // the reason exists somewhere a person can act on.
      expect(failure.remedy, contains('were not the problem'));
      expect(failure.remedy, contains('error_sending_confirmation_email'));
    });

    test('A PROVIDER THAT DID NOT ANSWER IS UNREACHABLE, NOT A REFUSAL', () async {
      // **The inversion this taxonomy exists to prevent, in its second
      // direction.** `AuthRetryableFetchException` extends `AuthException`, so a
      // dead connection was caught by the refusal clause and reported as one —
      // and it shipped: an ISP hijacking DNS for the provider's domain produced
      // "that account could not be created", which sends the owner to check an
      // account that was never the problem. A 5xx arrives the same way and means
      // the same thing from here: it did not answer.
      final failure = await _failureOf(
        () => _repository(
          FakeSecretStore(),
          ScriptedAuth(status: 500, reply: const <String, Object?>{}),
          ScriptedServer(),
        ).createAccount(
          url: _url,
          email: 'new@example.com',
          password: 'a long enough one',
        ),
      );

      expect(failure, isA<IdentityUnreachable>());
      expect(failure, isNot(isA<IdentityRefused>()));
      expect(failure, isNot(isA<IdentityUnrecognised>()));
      // It says the password was never sent, and it offers a retry — the two
      // things a refusal must never say.
      expect(failure!.remedy, contains('never sent'));
      expect(failure.canRetry, isTrue);
    });

    test('an uninvited email gets a real account and a refused server', () async {
      // The two gates are separate and the second one is ours. This is the
      // designed outcome, not a bug to route around.
      final store = FakeSecretStore();
      final failure = await _failureOf(
        () => _repository(
          store,
          ScriptedAuth(),
          ScriptedServer(reply: const ServerReply(403)),
        ).createAccount(
          url: _url,
          email: 'stranger@example.com',
          password: 'a long enough one',
        ),
      );

      expect(failure, isA<ServerRefusedThisAccount>());
      expect(await Credentials(store).apiToken(), isNull);
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
