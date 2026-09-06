/// The pairing screen, state by state.
///
/// The bar is Standards §3's: loading, error-with-retry and empty are all
/// rendered, and no state is a blank card. On top of that, this product's own
/// rule — every failure names itself and offers a way forward — is asserted
/// against the rendered text, not against the model, because the model being
/// right and the screen dropping it is exactly the failure mode.
///
/// **This half owns the FLOW**: the three shared async states, the account
/// route, the manual fallback and an already-paired phone. The named failures
/// are `pairing_failures_test.dart`; the host both pump is `_pairing_host.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/features/pairing/pairing_screen.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/toggle_row.dart';

import '../pairing/_pairing_fakes.dart';
import '_pairing_host.dart';

void main() {
  group('the three shared async states', () {
    testWidgets('loading names what it is waiting for', (tester) async {
      // pumpWidget lays out one frame and nothing more, so the keystore read
      // has not resolved. Pumping again would flush its microtask.
      await pumpPairing(tester, pairingHost(FakeSecretStore()));

      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Checking what is already paired'), findsOneWidget);
    });

    testWidgets('a keystore failure renders an error WITH a retry', (tester) async {
      await pumpPairing(
        tester,
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
      await pumpPairing(tester, pairingHost(FakeSecretStore()));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Zepp'), findsOneWidget);
      expect(find.text('Find my straps'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('the account route', () {
    testWidgets('the promise about the password is ON the form', (tester) async {
      await pumpPairing(tester, pairingHost(FakeSecretStore()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('goes to zepp.com and nowhere else'),
        findsOneWidget,
      );
    });

    testWidgets('remembering the sign-in is OFF by default', (tester) async {
      await pumpPairing(tester, pairingHost(FakeSecretStore()));
      await tester.pumpAndSettle();

      // v02 replaced the Material `Checkbox` with the prototype's own
      // `.toggle-row`; the opt-in default it carries is unchanged.
      final remember = tester.widget<ToggleRow>(find.byType(ToggleRow));
      expect(remember.value, isFalse);
      expect(find.textContaining('Leave this off and nothing about'), findsOneWidget);
    });

    testWidgets('signing in lists the account devices, named where named', (
      tester,
    ) async {
      await pumpPairing(tester, pairingHost(FakeSecretStore()));
      await tester.pumpAndSettle();
      await signInToZepp(tester);

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
      await pumpPairing(tester, pairingHost(FakeSecretStore()));
      await tester.pumpAndSettle();
      await signInToZepp(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm this strap'), findsOneWidget);
      expect(find.text(kPairingMac), findsOneWidget);
      expect(find.textContaining(kPairingAuthKey), findsNothing);
      expect(find.textContaining('not shown, and never sent anywhere'), findsOneWidget);
    });

    testWidgets('scan, then pair, and the summary says what was kept', (tester) async {
      final store = FakeSecretStore();
      await pumpPairing(tester, pairingHost(store));
      await tester.pumpAndSettle();
      await signInToZepp(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan for it'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Heard it — -61 dBm'), findsOneWidget);

      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();

      expect(find.text('Paired'), findsOneWidget);
      expect(store.values['strap_auth_key'], kPairingAuthKey);
      expect(
        find.textContaining('Nothing about your Zepp account was kept'),
        findsOneWidget,
      );
    });
  });

  group('the manual fallback', () {
    testWidgets('is reachable before any failure', (tester) async {
      await pumpPairing(tester, pairingHost(FakeSecretStore()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter the MAC and key by hand instead'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the pairing by hand'), findsOneWidget);
    });

    testWidgets('a malformed key is refused before anything is stored', (tester) async {
      final store = FakeSecretStore();
      await pumpPairing(tester, pairingHost(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter the MAC and key by hand instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, kPairingMac);
      await tester.enterText(find.byType(TextField).last, 'abc123');
      await tester.tap(find.text('Use this pairing'));
      await tester.pumpAndSettle();

      expect(find.text("That auth key isn't the right shape"), findsOneWidget);
      expect(find.textContaining('exactly 32 hex digits'), findsOneWidget);
      expect(store.values, isEmpty);
    });

    testWidgets('a good pairing typed by hand reaches the keystore', (tester) async {
      final store = FakeSecretStore();
      await pumpPairing(tester, pairingHost(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter the MAC and key by hand instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'db:98:1f:80:4c:3d');
      await tester.enterText(find.byType(TextField).last, '0x$kPairingAuthKey');
      await tester.tap(find.text('Use this pairing'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm this strap'), findsOneWidget);
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();

      expect(store.values['strap_mac'], kPairingMac);
      expect(store.values['strap_auth_key'], kPairingAuthKey);
    });
  });

  group('an already-paired phone', () {
    testWidgets('shows what is held rather than a form that would overwrite it', (
      tester,
    ) async {
      final store = FakeSecretStore()
        ..values['strap_mac'] = kPairingMac
        ..values['strap_auth_key'] = kPairingAuthKey;

      await pumpPairing(tester, pairingHost(store));
      await tester.pumpAndSettle();

      expect(find.text('Paired'), findsOneWidget);
      expect(find.text(kPairingMac), findsOneWidget);
      expect(find.text('Sign in to Zepp'), findsNothing);
      expect(find.text('Unpair'), findsOneWidget);
    });

    testWidgets('unpairing clears the keystore and returns to the form', (
      tester,
    ) async {
      final store = FakeSecretStore()
        ..values['strap_mac'] = kPairingMac
        ..values['strap_auth_key'] = kPairingAuthKey
        ..values['zepp_password'] = 'kept-earlier';

      await pumpPairing(tester, pairingHost(store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unpair'));
      await tester.pumpAndSettle();

      expect(store.values, isEmpty);
      expect(find.text('Sign in to Zepp'), findsOneWidget);
    });

    testWidgets('a remembered sign-in is admitted, not hidden', (tester) async {
      final store = FakeSecretStore()
        ..values['strap_mac'] = kPairingMac
        ..values['strap_auth_key'] = kPairingAuthKey
        ..values['zepp_email'] = 'owner@example.com'
        ..values['zepp_password'] = 'kept-earlier';

      await pumpPairing(tester, pairingHost(store));
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
