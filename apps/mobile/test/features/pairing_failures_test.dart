/// The pairing failures, one named message at a time.
///
/// This product's rule is that **every failure names itself and offers the
/// right way forward**, and it is asserted against the rendered text rather
/// than the model — the taxonomy in `pairing_failure.dart` being right and the
/// screen dropping it is exactly the failure mode this suite exists for. The
/// six cases are deliberately kept apart from one another: a wrong password and
/// a dead network reaching the same sentence is the defect, and only tests that
/// read both sentences can see it.
///
/// **This half owns the FAILURES.** The flow — the async states, the account
/// route, the manual fallback, an already-paired phone — is
/// `pairing_screen_test.dart`; the host both pump is `_pairing_host.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';

import '../pairing/_pairing_fakes.dart';
import '../pairing/_zepp_stub.dart';
import '_pairing_host.dart';

void main() {
  group('failures say which one, and offer the right way out', () {
    testWidgets('a wrong password names itself and offers no retry', (tester) async {
      await pumpPairing(
        tester,
        pairingHost(
          FakeSecretStore(),
          adapter: StubAdapter({'/v2/registrations/tokens': const StubReply(401)}),
        ),
      );
      await tester.pumpAndSettle();
      await signInToZepp(tester);

      expect(
        find.text('Zepp did not accept that email and password'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      // The form is still there to type into — the way forward is real.
      expect(find.text('Find my straps'), findsOneWidget);
    });

    testWidgets('an account with no straps is its own message', (tester) async {
      await pumpPairing(
        tester,
        pairingHost(
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
      await signInToZepp(tester);

      expect(
        find.text('That Zepp account has no devices bound to it'),
        findsOneWidget,
      );
      expect(find.textContaining('Pair the strap in the Zepp app once'), findsOneWidget);
    });

    testWidgets('a dead network is a retryable error, distinct from a bad password', (
      tester,
    ) async {
      await pumpPairing(
        tester,
        pairingHost(
          FakeSecretStore(),
          adapter: StubAdapter({'/v2/registrations/tokens': const StubReply(503)}),
        ),
      );
      await tester.pumpAndSettle();
      await signInToZepp(tester);

      expect(find.textContaining('is not one this app understands'), findsOneWidget);
      expect(find.textContaining('manual entry'), findsWidgets);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Bluetooth off is named, and pairing stays possible', (tester) async {
      await pumpPairing(
        tester,
        pairingHost(
          FakeSecretStore(),
          scanner: FakeStrapScanner(failure: const BluetoothOff()),
        ),
      );
      await tester.pumpAndSettle();
      await signInToZepp(tester);
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
      await pumpPairing(
        tester,
        pairingHost(
          FakeSecretStore(),
          scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
        ),
      );
      await tester.pumpAndSettle();
      await signInToZepp(tester);
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
      await pumpPairing(
        tester,
        pairingHost(
          FakeSecretStore(),
          scanner: FakeStrapScanner(
            outcome: const ScanNotPossibleHere('iOS never exposes a MAC.'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await signInToZepp(tester);
      await tester.tap(find.text('Helio Strap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan for it'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot check here'), findsOneWidget);
      expect(find.text('iOS never exposes a MAC.'), findsOneWidget);
    });
  });
}
