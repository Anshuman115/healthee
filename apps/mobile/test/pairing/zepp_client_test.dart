/// The three Zepp calls, against fixtures — and every branch of the taxonomy.
///
/// The point of the failure cases is not coverage. Each one asserts that a
/// DIFFERENT thing going wrong produces a DIFFERENT named failure, because the
/// product rule is that the app says which problem this is. A test suite where
/// every failure path landed on the same catch-all would pass just as green and
/// would be testing the bug.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/pairing/pairing_exception.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/pairing/zepp_session.dart';

import '_zepp_stub.dart';

const ZeppSession _session = ZeppSession(userId: '1234567890', appToken: 'APP-TOKEN');

Future<PairingFailure> failureFrom(Future<void> Function() run) async {
  try {
    await run();
  } on PairingException catch (error) {
    return error.failure;
  }
  fail('expected a PairingException');
}

void main() {
  group('sign-in, on the happy path', () {
    test('reads the app token and user id out of the fixtures', () async {
      final adapter = happyPathAdapter();

      final session = await clientWith(
        adapter,
      ).signIn(email: 'owner@example.com', password: 'hunter2');

      expect(session.userId, '1234567890');
      expect(session.appToken, 'APP-TOKEN-PLACEHOLDER-2f6d9');
    });

    test('the redirect is NOT followed — its Location is the answer', () async {
      final adapter = happyPathAdapter();

      await clientWith(adapter).signIn(email: 'e', password: 'p');

      final tokens = adapter.sent.first;
      expect(tokens.followRedirects, isFalse);
      // The `x-hm-ekv` header is what tells Zepp the body is encrypted; without
      // it the gateway reads the ciphertext as a form and rejects it.
      expect(tokens.headers['x-hm-ekv'], '1');
    });

    test('the step-1 body on the wire is ciphertext, not the password', () async {
      final adapter = happyPathAdapter();

      await clientWith(adapter).signIn(email: 'e', password: 'sup3r-secret-pw');

      final body = adapter.bodies.first;
      expect(body.length % 16, 0, reason: 'AES-CBC output is block-aligned');
      expect(
        String.fromCharCodes(body),
        isNot(contains('sup3r-secret-pw')),
        reason: 'the plaintext password must never reach the socket',
      );
    });
  });

  group('the device list', () {
    test('parses the usable devices and drops the one with no key', () async {
      final devices = await clientWith(happyPathAdapter()).devices(_session);

      expect(devices, hasLength(2));
      expect(devices.first.strap.mac, 'DB:98:1F:80:4C:3D');
      expect(devices.first.strap.authKey, 'a1b2c3d4e5f60718293a4b5c6d7e8f90');
      expect(devices.first.isActive, isTrue);
      expect(devices.first.label, 'Helio Strap');
    });

    test('a device Zepp did not name falls back to its MAC and says so', () async {
      final devices = await clientWith(happyPathAdapter()).devices(_session);
      final unnamed = devices[1];

      expect(unnamed.hasVendorName, isFalse);
      expect(unnamed.label, 'C0:FF:EE:11:22:33');
      // The key normalises to lower case whatever the payload used.
      expect(unnamed.strap.authKey, '00112233445566778899aabbccddeeff');
    });

    test('the app token rides in the apptoken header, not a query param', () async {
      final adapter = happyPathAdapter();

      await clientWith(adapter).devices(_session);

      final request = adapter.sent.single;
      expect(request.headers['apptoken'], 'APP-TOKEN');
      expect(request.uri.query, isNot(contains('APP-TOKEN')));
      // `r` is sent twice and the userid is in both path and query — the shape
      // the reference sends, which Zepp's gateway is picky about.
      expect(request.uri.queryParametersAll['r'], hasLength(2));
      expect(request.uri.path, contains('/users/1234567890/devices'));
    });
  });

  group('every failure is named, and they are not the same name', () {
    test('a rejected password is wrong-credentials, not an API change', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({'/v2/registrations/tokens': const StubReply(401)}),
        ).signIn(email: 'e', password: 'p'),
      );

      expect(failure, isA<WrongZeppCredentials>());
      expect(failure.canRetry, isFalse);
    });

    test('a redirect carrying an error code is also wrong-credentials', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({
            '/v2/registrations/tokens': StubReply.redirect(
              'https://example.com/cb?error=invalid_grant&state=REDIRECTION',
            ),
          }),
        ).signIn(email: 'e', password: 'p'),
      );

      expect(failure, isA<WrongZeppCredentials>());
    });

    test('a dead connection is no-network, and nothing was sent', () async {
      final failure = await failureFrom(
        () => clientWith(OfflineAdapter()).signIn(email: 'e', password: 'p'),
      );

      expect(failure, isA<NoNetwork>());
      expect(failure.remedy, contains('nothing was sent'));
    });

    test('a 200 where a redirect belongs is an API change', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({'/v2/registrations/tokens': const StubReply(200, body: 'ok')}),
        ).signIn(email: 'e', password: 'p'),
      );

      expect(failure, isA<ZeppApiChanged>());
      expect((failure as ZeppApiChanged).detail, contains('expected a redirect'));
    });

    test('a redirect with no tokens in it is an API change', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({
            '/v2/registrations/tokens': StubReply.redirect(
              'https://example.com/cb?state=REDIRECTION',
            ),
          }),
        ).signIn(email: 'e', password: 'p'),
      );

      expect(failure, isA<ZeppApiChanged>());
      expect((failure as ZeppApiChanged).detail, 'no access token in the redirect');
    });

    test('a login reply with no app_token is an API change', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({
            '/v2/registrations/tokens': StubReply.redirect(
              fixture('zepp_token_redirect.txt'),
            ),
            '/v2/client/login': const StubReply(
              200,
              body: '{"token_info": {"user_id": "1"}}',
            ),
          }),
        ).signIn(email: 'e', password: 'p'),
      );

      expect(failure, isA<ZeppApiChanged>());
      expect((failure as ZeppApiChanged).detail, 'no app_token in the reply');
    });

    test('a non-JSON reply is an API change, and does not quote the body', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({
            '/v2/registrations/tokens': StubReply.redirect(
              fixture('zepp_token_redirect.txt'),
            ),
            '/v2/client/login': const StubReply(
              200,
              body: '<html>maintenance SECRET-IN-BODY</html>',
            ),
          }),
        ).signIn(email: 'e', password: 'p'),
      );

      expect(failure, isA<ZeppApiChanged>());
      expect(failure.remedy, isNot(contains('SECRET-IN-BODY')));
    });

    test('an empty items list is no-bound-devices, which is not retryable', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({'/devices': const StubReply(200, body: '{"items": []}')}),
        ).devices(_session),
      );

      expect(failure, isA<NoBoundDevices>());
      expect(failure.canRetry, isFalse);
    });

    test('devices that all lack keys read as no-bound-devices too', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({
            '/devices': const StubReply(
              200,
              body: '{"items": [{"macAddress": "AA:BB:CC:DD:EE:FF",'
                  ' "additionalInfo": "{}"}]}',
            ),
          }),
        ).devices(_session),
      );

      expect(failure, isA<NoBoundDevices>());
    });

    test('a 403 on the device list is an API change, with the status named', () async {
      final failure = await failureFrom(
        () => clientWith(
          StubAdapter({'/devices': const StubReply(403)}),
        ).devices(_session),
      );

      expect(failure, isA<ZeppApiChanged>());
      expect((failure as ZeppApiChanged).detail, 'HTTP 403');
      expect(failure.step, 'the device list');
    });
  });
}
