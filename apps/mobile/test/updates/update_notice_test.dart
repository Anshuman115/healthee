/// What the About screen says about updates, in each state of the check.
///
/// The state that matters most is the one nobody designs for: the check that
/// could not be made. It must say so — not fall back to "you are up to date",
/// which is the app reassuring somebody about something it has not established.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/updates/app_release.dart';
import 'package:healthee/data/updates/update_check.dart';
import 'package:healthee/features/settings/widgets/update_notice.dart';

AppRelease _release() => const AppRelease(
  tag: 'v0.2.0',
  versionCode: 7,
  notes: 'notes',
  downloadUrl: 'https://example.test/healthee-v0.2.0.apk',
  sizeBytes: 1,
);

void main() {
  group('the line each state produces', () {
    test('an update names the version, so it is a decision not a nudge', () {
      expect(
        updateLine(AsyncData<UpdateStatus>(UpdateAvailable(_release()))),
        'Version 0.2.0 is available',
      );
    });

    test('up to date says so plainly', () {
      expect(
        updateLine(const AsyncData<UpdateStatus>(UpToDate())),
        'This is the latest build',
      );
    });

    test('UNKNOWN SAYS IT COULD NOT CHECK — never "up to date"', () {
      final line = updateLine(const AsyncData<UpdateStatus>(UpdateUnknown()));

      expect(line, "Couldn't check for updates");
      expect(line, isNot(contains('latest')));
    });

    test('and a provider error says the same thing, because it means the same', () {
      expect(
        updateLine(AsyncError<UpdateStatus>(Exception('x'), StackTrace.empty)),
        "Couldn't check for updates",
      );
    });

    test('while it is still checking it claims nothing', () {
      final line = updateLine(const AsyncLoading<UpdateStatus>());

      expect(line, 'Checking for a newer build…');
      expect(line, isNot(contains('latest')));
    });
  });

  test('the link goes to the RELEASE PAGE, not straight at the binary', () {
    // A browser pointed at a 72 MB asset starts a download with no context. The
    // notes are what tell the owner whether they want it.
    final uri = releasePage(_release());

    expect(uri.toString(), 'https://github.com/afkcodes/healthee/releases/tag/v0.2.0');
    expect(uri.path, isNot(endsWith('.apk')));
  });
}
