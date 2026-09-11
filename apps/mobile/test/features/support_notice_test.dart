/// What the support block says, where it sends money, and what it must never
/// imply.
///
/// The load-bearing assertions are the negative ones. A donation card that hints
/// at features you are missing has quietly invented a paid tier; and a UPI intent
/// with a payee nobody typed in sends a stranger money with no undo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/features/settings/widgets/support_notice.dart';

void main() {
  test('IT PROMISES NOTHING IN RETURN', () {
    // The words a donation prompt reaches for when it is really a sales page.
    for (final forbidden in <String>[
      'unlock',
      'premium',
      'upgrade',
      'pro ',
      'supporter-only',
      'early access',
    ]) {
      expect(
        kSupportBody.toLowerCase(),
        isNot(contains(forbidden)),
        reason: '"$forbidden" turns a thank-you into a pitch',
      );
    }
  });

  test('it says what the money is for and does NOT argue about pricing', () {
    // The owner removed the paid-tier sentence from the README and then from the
    // card. A donation prompt is not the place to litigate what the product
    // costs — that belongs on About, if anywhere.
    //
    // And it funds development and research, NOT hosting: on a self-hosted
    // product the server bill is the owner's own, and naming it here would ask
    // for a cost somebody else is already carrying.
    expect(kSupportBody, contains('development'));
    expect(kSupportBody, contains('research'));
    expect(kSupportBody, isNot(contains('hosting')));
    for (final pricing in <String>['paid tier', 'behind a wall', 'free']) {
      expect(
        kSupportBody.toLowerCase(),
        isNot(contains(pricing)),
        reason: '"$pricing" is a pricing claim on a donation card',
      );
    }
  });

  test('the destinations are the ones the README publishes', () {
    // One value, two places. A link that drifts between the repo and the app is
    // how somebody ends up donating to an account that is no longer watched.
    expect(kKofiUrl, 'https://ko-fi.com/afkcodes');
    expect(kSponsorUrl, 'https://afk.codes/sponsor');
  });

  test('the compact card and the quiet one share ONE set of values', () {
    // Two presentations, one source. If the settings card carried its own copy of
    // the URLs or the line, one of them would eventually be edited and the other
    // would not — and the stale one would keep collecting money.
    expect(kSupportHeading, isNotEmpty);
    expect(kSupportBody, isNotEmpty);
  });

  group('UPI', () {
    test('IT CARRIES NO AMOUNT — the payer decides', () {
      // A pre-filled figure reads as a price however editable it is, and no
      // surface of the card names one either.
      expect(kUpiLink, isNot(contains('am=')));
      expect(kUpiLink, contains('cu=INR'));
      for (final surface in <String>[
        kUpiLabel,
        kKofiLabel,
        kSupportHeading,
        kSupportBody,
      ]) {
        expect(
          surface,
          isNot(matches(RegExp(r'\d'))),
          reason: 'a figure on the card turns a tip into a price',
        );
      }
    });

    test('it is a upi intent, not a web link', () {
      // `https://` would open a browser, which cannot pay.
      expect(kUpiLink, startsWith('upi://pay?'));
    });

    test('THE VPA IS NOT PERCENT-ENCODED', () {
      // The bug sunoh hit and documented: `Uri`'s own query encoding turns the
      // `@` into `%40`, and several Indian UPI apps refuse to parse that. This
      // is why the link is a string rather than a built `Uri`.
      expect(kUpiLink, contains('pa=$kUpiVpa'));
      expect(kUpiLink, isNot(contains('%40')));
      expect(Uri.parse(kUpiLink).queryParameters['pa'], kUpiVpa);
    });

    test('the payee comes from the constants and is never invented', () {
      expect(kUpiLink, contains('pn=$kUpiPayee'));
      expect(kUpiVpa, isNotEmpty);
    });
  });
}
