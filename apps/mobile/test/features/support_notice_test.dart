/// What the support block says, and what it must never imply.
///
/// The load-bearing assertion is the negative one. An ask that leaves the reader
/// wondering whether they are missing features has quietly invented a paid tier —
/// in a product whose `SELF_HOST_UNLOCKED` exists precisely so a self-hoster
/// paying their own AI bill gets the whole thing. Saying that beside the link
/// matters more than the link.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/features/settings/widgets/support_notice.dart';

void main() {
  test('it says plainly that nothing is behind a wall', () {
    expect(kSupportBody, contains('no paid tier'));
    expect(kSupportBody, contains('nothing unlocks'));
  });

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
        kSupportBody.toLowerCase().replaceAll('nothing unlocks', ''),
        isNot(contains(forbidden)),
        reason: '"$forbidden" turns a thank-you into a pitch',
      );
    }
  });

  test('both destinations are the ones the README publishes', () {
    // One value, two places. A link that drifts between the repo and the app is
    // how somebody ends up donating to an account that is no longer watched.
    expect(kKofiUrl, 'https://ko-fi.com/afkcodes');
    expect(kSponsorUrl, 'https://afk.codes/sponsor');
  });
}
