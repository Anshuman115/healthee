/// Three answers, and the third one is the point.
///
/// "Up to date" and "an update is available" are claims about the world. "We could
/// not check" is what an offline phone, a rate limit, a repo with no releases and a
/// host with no plugin registrant all actually produce — and reporting any of them
/// as "up to date" would be the app reassuring somebody about something it does not
/// know. That is the one thing this product refuses to do, so it is what these
/// tests spend most of their assertions on.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/updates/app_release.dart';
import 'package:healthee/data/updates/update_check.dart';

AppRelease _release({int versionCode = 7}) => AppRelease(
  tag: 'v0.2.0',
  versionCode: versionCode,
  notes: 'notes',
  downloadUrl: 'https://example.test/healthee.apk',
  sizeBytes: 1,
);

void main() {
  group('a comparison it can actually make', () {
    test('a higher published build is an update', () {
      final status = statusFor(current: 6, release: _release());

      expect(status, isA<UpdateAvailable>());
      expect((status as UpdateAvailable).release.versionName, '0.2.0');
    });

    test('the same build is up to date', () {
      expect(statusFor(current: 7, release: _release()), isA<UpToDate>());
    });

    test('a LOWER published build is up to date, not a downgrade offer', () {
      // A release can be pulled and an older one become "latest". Offering it
      // would be a download Android then refuses as a downgrade.
      expect(statusFor(current: 9, release: _release()), isA<UpToDate>());
    });
  });

  group('WHAT IT CANNOT ESTABLISH IT DOES NOT CLAIM', () {
    test('no release read → unknown, NEVER up to date', () {
      // Offline, rate-limited, no releases published, an unparseable body. The
      // reassuring answer is the wrong one and it is the tempting one.
      final status = statusFor(current: 7, release: null);

      expect(status, isA<UpdateUnknown>());
      expect(status, isNot(isA<UpToDate>()));
    });

    test('no build number → unknown, NEVER an update prompt', () {
      // A host with no plugin registrant cannot say what it is running. Prompting
      // to "update" from an unknown version is a guess with a button on it.
      final status = statusFor(current: null, release: _release());

      expect(status, isA<UpdateUnknown>());
      expect(status, isNot(isA<UpdateAvailable>()));
    });

    test('neither half → still one honest answer', () {
      expect(statusFor(current: null, release: null), isA<UpdateUnknown>());
    });
  });
}
