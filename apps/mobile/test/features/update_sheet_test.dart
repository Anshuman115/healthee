/// The update sheet asks ONCE, and only about something it actually established.
///
/// Both assertions are negative and both are the point. An app that interrupts
/// you every cold start about a sideloaded update nobody needs is a nag; an app
/// that interrupts you to say it could not reach GitHub has interrupted you for
/// nothing at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/updates/app_release.dart';
import 'package:healthee/data/updates/update_check.dart';
import 'package:healthee/data/updates/update_prompt_store.dart';
import 'package:healthee/features/settings/widgets/update_sheet.dart';

AppRelease _release(int code) => AppRelease(
  tag: 'v9.9.9',
  versionCode: code,
  notes: 'notes',
  downloadUrl: 'https://example.com/app.apk',
  sizeBytes: 1,
);

void main() {
  group('it asks once per release', () {
    test('a release nobody has been shown is offered', () {
      expect(
        UpdatePromptStore.shouldOffer(versionCode: 7, offered: null),
        isTrue,
      );
    });

    test('THE SAME RELEASE IS NOT OFFERED TWICE', () {
      // The nag, in its plainest form: this returning true is the sheet opening
      // on every cold start for a version already declined.
      expect(UpdatePromptStore.shouldOffer(versionCode: 7, offered: 7), isFalse);
    });

    test('a NEWER release is offered again', () {
      expect(UpdatePromptStore.shouldOffer(versionCode: 8, offered: 7), isTrue);
    });

    test('an OLDER release cannot re-open the sheet by going backwards', () {
      // Greater-than rather than not-equal. A release yanked and replaced by a
      // lower code must not read as "something new to say".
      expect(UpdatePromptStore.shouldOffer(versionCode: 6, offered: 7), isFalse);
    });
  });

  group('only a real update opens it', () {
    test('an established newer build is an offer', () {
      final status = statusFor(current: 5, release: _release(6));
      expect(status, isA<UpdateAvailable>());
    });

    test('UP TO DATE OPENS NOTHING', () {
      expect(statusFor(current: 6, release: _release(6)), isA<UpToDate>());
    });

    test('AND NEITHER DOES "WE COULD NOT CHECK"', () {
      // Offline, rate-limited, no release published. The honest third answer
      // exists so it is never dressed up as one of the other two — and it is
      // the one that must never interrupt anybody.
      expect(statusFor(current: 5, release: null), isA<UpdateUnknown>());
      expect(statusFor(current: null, release: _release(6)), isA<UpdateUnknown>());
    });
  });

  test('the sheet says the install leaves the app', () {
    // Somebody expecting a one-tap in-app update should learn otherwise here,
    // not after a browser opens on a 72 MB binary.
    expect(kUpdateSheetBody.toLowerCase(), contains('browser'));
    expect(kUpdateSheetBody.toLowerCase(), contains('android'));
    expect(kUpdateSheetTitle, isNotEmpty);
  });
}
