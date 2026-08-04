/// The pairing screen, state by state.
///
/// The bar is Standards §3's: loading, error-with-retry and empty are all
/// rendered, and no state is a blank card. On top of that, this product's own
/// rule — every failure names itself and offers a way forward — is asserted
/// against the rendered text, not against the model, because the model being
/// right and the screen dropping it is exactly the failure mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/features/pairing/pairing_screen.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

import '../pairing/_pairing_fakes.dart';
import '../pairing/_zepp_stub.dart';

const String _mac = 'DB:98:1F:80:4C:3D';
const String _authKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

Widget _host(FakeSecretStore store, {StubAdapter? adapter, FakeStrapScanner? scanner}) {
  return ProviderScope(
    overrides: [
      credentialsProvider.overrideWithValue(Credentials(store)),
      pairingRepositoryProvider.overrideWithValue(
        PairingRepository(
          credentials: Credentials(store),
          zepp: clientWith(adapter ?? happyPathAdapter()),
          scanner: scanner ?? FakeStrapScanner(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const PairingScreen(),
    ),
  );
}

/// Fills the sign-in form and submits it.
Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'owner@example.com');
  await tester.enterText(find.byType(TextField).last, 'hunter2');
  await tester.tap(find.text('Find my straps'));
  await tester.pumpAndSettle();
}

void main() {
  group('the three shared async states', () {
    testWidgets('loading names what it is waiting for', (tester) async {
      // pumpWidget lays out one frame and nothing more, so the keystore read
      // has not resolved. Pumping again would flush its microtask.
      await tester.pumpWidget(_host(FakeSecretStore()));

      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Checking what is already paired'), findsOneWidget);
    });

    testWidgets('a keystore failure renders an error WITH a retry', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pairingSummaryProvider.overrideWith(
              (ref) => Future<({PairedStrap? strap, bool zeppRemembered})>.error(
                StateError('keystore unavailable'),
              ),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const PairingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't read this phone's keystore"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('nothing paired renders the form, not a blank card', (tester) async {
      await tester.pumpWidget(_host(FakeSecretStore()));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Zepp'), findsOneWidget);
      expect(find.text('Find my straps'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('the account route', () {
    testWidgets('the promise about the password is ON the form', (tester) async {
      await tester.pumpWidget(_host(FakeSecretStore()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('goes to zepp.com and nowhere else'),
        findsOneWidget,
      );
    });

    testWidgets('remembering the sign-in is OFF by default', (tester) async {
      await tester.pumpWidget(_host(FakeSecretStore()));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      expect(find.textContaining('Leave this off and nothing about'), findsOneWidget);
    });

    testWidgets('signing in lists the account devices, named where named', (
      tester,
    ) async {
      await tester.pumpWidget(_host(FakeSecretStore()));
      await tester.pumpAndSettle();
      await _signIn(tester);

      expect(find.text('Your Zepp devices'), findsOneWidget);
      expect(find.text('Helio Strap'), findsOneWidget);
      // The unnamed one shows its MAC and admits Zepp gave no name.
      expect(find.text('C0:FF:EE:11:22:33'), findsOneWidget);
      expect(find.text('Zepp did not name this one'), findsOneWidget);
      // The keyless third device is not offered at all.
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsNothing);
    });

    testWidgets('picking one leads to confirmation, and never shows the key', (
      tester,
    ) async {
      await tester.pumpWidget(_host(FakeSecretStore()));
      await tester.pumpAndSettle();
      await _signIn(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm this strap'), findsOneWidget);
      expect(find.text(_mac), findsOneWidget);
      expect(find.textContaining(_authKey), findsNothing);
      expect(find.textContaining('not shown, and never sent anywhere'), findsOneWidget);
    });

    testWidgets('scan, then pair, and the summary says what was kept', (tester) async {
      final store = FakeSecretStore();
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await _signIn(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan for it'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Heard it — -61 dBm'), findsOneWidget);

      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();

      expect(find.text('Paired'), findsOneWidget);
      expect(store.values['strap_auth_key'], _authKey);
      expect(
        find.textContaining('Nothing about your Zepp account was kept'),
        findsOneWidget,
      );
    });
  });

  group('failures say which one, and offer the right way out', () {
    testWidgets('a wrong password names itself and offers no retry', (tester) async {
      await tester.pumpWidget(
        _host(
          FakeSecretStore(),
          adapter: StubAdapter({'/v2/registrations/tokens': const StubReply(401)}),
        ),
      );
      await tester.pumpAndSettle();
      await _signIn(tester);

      expect(
        find.text('Zepp did not accept that email and password'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      // The form is still there to type into — the way forward is real.
      expect(find.text('Find my straps'), findsOneWidget);
    });

    testWidgets('an account with no straps is its own message', (tester) async {
      await tester.pumpWidget(
        _host(
          FakeSecretStore(),
          adapter: StubAdapter({
            '/v2/registrations/tokens': StubReply.redirect(
              fixture('zepp_token_redirect.txt'),
            ),
            '/v2/client/login': StubReply(200, body: fixture('zepp_login.json')),
            '/devices': const StubReply(200, body: '{"items": []}'),
          }),
        ),
      );
      await tester.pumpAndSettle();
      await _signIn(tester);

      expect(
        find.text('That Zepp account has no devices bound to it'),
        findsOneWidget,
      );
      expect(find.textContaining('Pair the strap in the Zepp app once'), findsOneWidget);
    });

    testWidgets('a dead network is a retryable error, distinct from a bad password', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          FakeSecretStore(),
          adapter: StubAdapter({'/v2/registrations/tokens': const StubReply(503)}),
        ),
      );
      await tester.pumpAndSettle();
      await _signIn(tester);

      expect(find.textContaining('is not one this app understands'), findsOneWidget);
      expect(find.textContaining('manual entry'), findsWidgets);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Bluetooth off is named, and pairing stays possible', (tester) async {
      await tester.pumpWidget(
        _host(
          FakeSecretStore(),
          scanner: FakeStrapScanner(failure: const BluetoothOff()),
        ),
      );
      await tester.pumpAndSettle();
      await _signIn(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan for it'));
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // Confirmation is evidence, not a gate: a correct pairing is still savable.
      expect(find.text('Pair'), findsOneWidget);
    });

    testWidgets('a strap out of range says how long it listened', (tester) async {
      await tester.pumpWidget(
        _host(
          FakeSecretStore(),
          scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
        ),
      );
      await tester.pumpAndSettle();
      await _signIn(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan for it'));
      await tester.pumpAndSettle();

      expect(find.textContaining("didn't advertise in 12 seconds"), findsOneWidget);
      expect(find.textContaining('already connected elsewhere'), findsOneWidget);
    });

    testWidgets('a platform that hides MAC addresses says so, not "not in range"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          FakeSecretStore(),
          scanner: FakeStrapScanner(
            outcome: const ScanNotPossibleHere('iOS never exposes a MAC.'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _signIn(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan for it'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot check here'), findsOneWidget);
      expect(find.text('iOS never exposes a MAC.'), findsOneWidget);
    });
  });

  group('the manual fallback', () {
    testWidgets('is reachable before any failure', (tester) async {
      await tester.pumpWidget(_host(FakeSecretStore()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter the MAC and key by hand instead'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the pairing by hand'), findsOneWidget);
    });

    testWidgets('a malformed key is refused before anything is stored', (tester) async {
      final store = FakeSecretStore();
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter the MAC and key by hand instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, _mac);
      await tester.enterText(find.byType(TextField).last, 'abc123');
      await tester.tap(find.text('Use this pairing'));
      await tester.pumpAndSettle();

      expect(find.text("That auth key isn't the right shape"), findsOneWidget);
      expect(find.textContaining('exactly 32 hex digits'), findsOneWidget);
      expect(store.values, isEmpty);
    });

    testWidgets('a good pairing typed by hand reaches the keystore', (tester) async {
      final store = FakeSecretStore();
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter the MAC and key by hand instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'db:98:1f:80:4c:3d');
      await tester.enterText(find.byType(TextField).last, '0x$_authKey');
      await tester.tap(find.text('Use this pairing'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm this strap'), findsOneWidget);
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();

      expect(store.values['strap_mac'], _mac);
      expect(store.values['strap_auth_key'], _authKey);
    });
  });

  group('an already-paired phone', () {
    testWidgets('shows what is held rather than a form that would overwrite it', (
      tester,
    ) async {
      final store = FakeSecretStore()
        ..values['strap_mac'] = _mac
        ..values['strap_auth_key'] = _authKey;

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('Paired'), findsOneWidget);
      expect(find.text(_mac), findsOneWidget);
      expect(find.text('Sign in to Zepp'), findsNothing);
      expect(find.text('Unpair'), findsOneWidget);
    });

    testWidgets('unpairing clears the keystore and returns to the form', (
      tester,
    ) async {
      final store = FakeSecretStore()
        ..values['strap_mac'] = _mac
        ..values['strap_auth_key'] = _authKey
        ..values['zepp_password'] = 'kept-earlier';

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unpair'));
      await tester.pumpAndSettle();

      expect(store.values, isEmpty);
      expect(find.text('Sign in to Zepp'), findsOneWidget);
    });

    testWidgets('a remembered sign-in is admitted, not hidden', (tester) async {
      final store = FakeSecretStore()
        ..values['strap_mac'] = _mac
        ..values['strap_auth_key'] = _authKey
        ..values['zepp_email'] = 'owner@example.com'
        ..values['zepp_password'] = 'kept-earlier';

      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your Zepp email and password are also in the keystore'),
        findsOneWidget,
      );
      // …and the password itself is nowhere on screen.
      expect(find.textContaining('kept-earlier'), findsNothing);
    });
  });
}
