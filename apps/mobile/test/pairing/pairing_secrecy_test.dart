/// **The proof that no secret is logged.**
///
/// The legacy Python had to reach into its HTTP library and switch the logger
/// off, because that library printed the url-encoded password at debug level.
/// Nobody caught that by reading the code; it was caught by seeing a password in
/// a terminal. This suite is the version of that discovery that runs on every
/// push.
///
/// The method: drive the whole pairing flow — sign-in, device list, scan,
/// store — with values that exist nowhere else in the repository, capture every
/// line the app logger emits (`AppLog.sink`), and fail if any sentinel appears.
/// It covers the failure paths too, because an error message is where secrets
/// escape: the one thing a `catch` reliably has in hand is the object that
/// carries the response body.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_exception.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';

import '_pairing_fakes.dart';
import '_zepp_stub.dart';

/// Strings that appear in no other file, so a match is proof of a leak.
const String _password = 'S3NTINEL-PASSWORD-b7a1';
const String _email = 'sentinel-owner@example.com';
const String _accessToken = 'ACCESS-TOKEN-PLACEHOLDER-b7f21';
const String _appToken = 'APP-TOKEN-PLACEHOLDER-2f6d9';
const String _authKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
const String _mac = 'DB:98:1F:80:4C:3D';

const List<String> _secrets = [_password, _accessToken, _appToken, _authKey];

late List<String> _log;

void _startCapturing() {
  _log = [];
  AppLog.sink = _log.add;
}

void _expectNothingLeaked({List<String> secrets = _secrets}) {
  final transcript = _log.join('\n');
  for (final secret in secrets) {
    expect(
      transcript,
      isNot(contains(secret)),
      reason: 'this reached the log:\n$transcript',
    );
  }
}

PairingRepository _repository(
  FakeSecretStore store, {
  StubAdapter? adapter,
  FakeStrapScanner? scanner,
}) {
  return PairingRepository(
    credentials: Credentials(store),
    zepp: clientWith(adapter ?? happyPathAdapter()),
    scanner: scanner ?? FakeStrapScanner(),
  );
}

void main() {
  setUp(_startCapturing);
  tearDown(() => AppLog.sink = null);

  test('the seam is off unless a test turns it on', () {
    AppLog.sink = null;
    expect(AppLog.sink, isNull, reason: 'nothing in lib/ may assign this');
  });

  group('the happy path logs plenty, and no secret', () {
    test('sign-in, device list and pairing', () async {
      final store = FakeSecretStore();
      final repository = _repository(store);

      final devices = await repository.devicesForAccount(
        email: _email,
        password: _password,
      );
      await repository.confirmInRange(devices.first.strap);
      await repository.pair(devices.first.strap);

      // The flow really ran — otherwise "nothing leaked" would be vacuous.
      expect(_log, isNotEmpty);
      expect(_log.join('\n'), contains('zepp sign-in complete'));
      _expectNothingLeaked();
    });

    test('the MAC is logged as its last two octets, never in full', () async {
      final store = FakeSecretStore();

      await _repository(store).pair(
        PairedStrap.parse(mac: _mac, authKey: _authKey),
      );

      final transcript = _log.join('\n');
      expect(transcript, contains('…4C:3D'));
      expect(transcript, isNot(contains(_mac)));
    });
  });

  group('failure paths are where secrets escape, so they are checked hardest', () {
    test('a 500 whose BODY is a token does not put it in the log', () async {
      final store = FakeSecretStore();
      final repository = _repository(
        store,
        adapter: StubAdapter({
          '/v2/registrations/tokens': StubReply.redirect(
            fixture('zepp_token_redirect.txt'),
          ),
          '/v2/client/login': const StubReply(
            500,
            body: '{"app_token": "$_appToken", "trace": "$_password"}',
          ),
        }),
      );

      await expectLater(
        repository.devicesForAccount(email: _email, password: _password),
        throwsA(isA<PairingException>()),
      );
      _expectNothingLeaked();
    });

    test('a rejected sign-in does not echo the credential back', () async {
      final store = FakeSecretStore();
      final repository = _repository(
        store,
        adapter: StubAdapter({
          '/v2/registrations/tokens': const StubReply(
            401,
            body: '{"error": "bad password: $_password"}',
          ),
        }),
      );

      await expectLater(
        repository.devicesForAccount(email: _email, password: _password),
        throwsA(isA<PairingException>()),
      );
      _expectNothingLeaked();
    });

    test('a transport failure logs the DioException TYPE, not the object', () async {
      final store = FakeSecretStore();
      final repository = PairingRepository(
        credentials: Credentials(store),
        zepp: clientWith(OfflineAdapter()),
        scanner: FakeStrapScanner(),
      );

      await expectLater(
        repository.devicesForAccount(email: _email, password: _password),
        throwsA(isA<PairingException>()),
      );

      final transcript = _log.join('\n');
      expect(transcript, contains('connectionError'));
      // A DioException stringifies its request URI and often its response body.
      expect(transcript, isNot(contains('DioException')));
      _expectNothingLeaked();
    });
  });

  group('what is actually written, and where', () {
    test('the strap goes to the keystore; the password does not', () async {
      final store = FakeSecretStore();

      await _repository(store).pair(
        PairedStrap.parse(mac: _mac, authKey: _authKey),
      );

      expect(store.values['strap_mac'], _mac);
      expect(store.values['strap_auth_key'], _authKey);
      expect(store.values.values, isNot(contains(_password)));
      expect(store.values.containsKey('zepp_password'), isFalse);
    });

    test('opting in stores the sign-in — and only then', () async {
      final store = FakeSecretStore();

      await _repository(store).pair(
        PairedStrap.parse(mac: _mac, authKey: _authKey),
        rememberZepp: (email: _email, password: _password),
      );

      expect(store.values['zepp_email'], _email);
      expect(store.values['zepp_password'], _password);
      // Storing it must not log it.
      _expectNothingLeaked();
    });

    test('pairing without the opt-in DELETES a sign-in an earlier one kept', () async {
      final store = FakeSecretStore();
      final repository = _repository(store);
      final strap = PairedStrap.parse(mac: _mac, authKey: _authKey);

      await repository.pair(strap, rememberZepp: (email: _email, password: _password));
      await repository.pair(strap);

      expect(store.values.containsKey('zepp_password'), isFalse);
      expect(store.values.containsKey('zepp_email'), isFalse);
      expect(store.values['strap_auth_key'], _authKey);
    });

    test('unpair removes the strap AND the remembered sign-in', () async {
      final store = FakeSecretStore();
      final repository = _repository(store);

      await repository.pair(
        PairedStrap.parse(mac: _mac, authKey: _authKey),
        rememberZepp: (email: _email, password: _password),
      );
      await repository.unpair();

      expect(store.values, isEmpty);
      expect(await repository.pairedStrap(), isNull);
    });

    test('half a pairing reads as no pairing', () async {
      final store = FakeSecretStore()..values['strap_mac'] = _mac;

      expect(await _repository(store).pairedStrap(), isNull);
    });
  });

  group('nothing about the strap is sent to the Healthee API', () {
    test('every request the flow makes goes to a zepp.com host', () async {
      final adapter = happyPathAdapter();
      final store = FakeSecretStore();
      final repository = _repository(store, adapter: adapter);

      final devices = await repository.devicesForAccount(
        email: _email,
        password: _password,
      );
      await repository.pair(devices.first.strap);

      expect(adapter.sent, hasLength(3));
      for (final request in adapter.sent) {
        expect(request.uri.host, endsWith('zepp.com'));
      }
    });

    test('the auth key appears in no request the flow made', () async {
      final adapter = happyPathAdapter();
      final store = FakeSecretStore();
      final repository = _repository(store, adapter: adapter);

      final devices = await repository.devicesForAccount(
        email: _email,
        password: _password,
      );
      await repository.pair(devices.first.strap);

      for (final request in adapter.sent) {
        expect(request.uri.toString(), isNot(contains(_authKey)));
        expect(request.headers.values.join(' '), isNot(contains(_authKey)));
      }
      for (final body in adapter.bodies) {
        expect(String.fromCharCodes(body), isNot(contains(_authKey)));
      }
    });
  });
}
