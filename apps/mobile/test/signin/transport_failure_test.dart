/// A dead connection is never reported as a refusal.
///
/// Split from `server_session_test.dart` when the mapping got its own module:
/// `data/api/transport_failure.dart` exists because two clients need it — the
/// probe that checks a credential and the one that mints a device token — and
/// the cases below are that module's, not the repository's.
///
/// The failure this prevents is a *refusal reported as a connection problem*, or
/// the reverse. "Couldn't reach the server" for a credential the server actually
/// read and rejected sends the owner to their router, their DNS and their
/// firewall for an evening, and none of those is where the answer is. So dio's
/// exception TYPE is not read as the answer: the wrapped cause is inspected
/// first, because a TLS handshake failure, a refused socket and a failed DNS
/// lookup all arrive as the same `connectionError`.
library;

import 'package:flutter_test/flutter_test.dart';
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
  group('unreachable is reported as unreachable, never as a refusal', () {
    Future<ServerSignInFailure?> unreachableWith(
      DioExceptionBuilder build,
    ) async {
      return _failureOf(
        () => repositoryWith(
          FakeSecretStore(),
          ScriptedServer(failWith: build),
        ).signInWithToken(url: _url, token: kSentinelToken),
      );
    }

    test('a failed DNS lookup is a connection problem, and says so', () async {
      final failure = await unreachableWith(
        hostNotFound('healthee.example.com'),
      );

      expect(failure, isA<ServerUnreachable>());
      expect(failure, isNot(isA<TokenRefused>()));
      expect(
        (failure! as ServerUnreachable).reason,
        UnreachableReason.hostNotFound,
      );
      expect(failure.headline, "Couldn't reach healthee.example.com");
      expect(failure.remedy, contains('not a wrong token'));
      expect(failure.remedy, contains('the name could not be looked up'));
      // Worth trying again, unlike a refusal — the difference the owner acts on.
      expect(failure.canRetry, isTrue);
    });

    test('a refused connection is its own sentence', () async {
      final failure = await unreachableWith(connectionRefused());

      expect((failure! as ServerUnreachable).reason, UnreachableReason.refused);
      expect(failure.remedy, contains('the connection was refused'));
    });

    test('a rejected certificate is TLS, not a dead network', () async {
      final failure = await unreachableWith(tlsRejected());

      expect(
        (failure! as ServerUnreachable).reason,
        UnreachableReason.tlsRejected,
      );
      expect(failure.remedy, contains('HTTPS certificate was rejected'));
    });

    test('a timeout is a timeout', () async {
      final failure = await unreachableWith(receiveTimeout());

      expect(
        (failure! as ServerUnreachable).reason,
        UnreachableReason.timedOut,
      );
      expect(failure.remedy, contains('did not answer in time'));
    });

    test('nothing is stored when nothing answered', () async {
      final store = FakeSecretStore();
      await _failureOf(
        () => repositoryWith(
          store,
          ScriptedServer(failWith: hostNotFound('healthee.example.com')),
        ).signInWithToken(url: _url, token: kSentinelToken),
      );

      expect(store.values, isEmpty);
    });

    test('the four reasons produce four distinguishable log codes', () async {
      final codes = <String>{};
      for (final build in [
        hostNotFound('healthee.example.com'),
        connectionRefused(),
        tlsRejected(),
        receiveTimeout(),
      ]) {
        codes.add((await unreachableWith(build))!.code);
      }
      expect(codes, hasLength(4));
    });
  });
}
