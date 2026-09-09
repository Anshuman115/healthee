/// The release manifest must carry every permission the app needs to RUN.
///
/// ## The failure this exists for
///
/// `android.permission.INTERNET` lived only in the `debug/` and `profile/`
/// manifests — the two Flutter generates for its own tooling. `main/` did not
/// declare it and there is no `release/` manifest, so **every debug build could
/// reach the server and every release build could not**: DNS failed inside the
/// process before a request left it.
///
/// It survived because a release build on a phone with a warm 60-day local
/// store still draws every screen from cache. Today, sleep, recovery,
/// biological age — all present, all stale, and only the writes missing. The
/// symptoms pointed everywhere except the manifest: a push that "could not be
/// reached", a sign-in whose host name "could not be looked up", zero
/// `POST /ingest` server-side, and a phone that answered `curl` in 400ms
/// because `adb shell` runs as the shell user rather than as the app.
///
/// A permission a debug build supplies for you is one a test has to hold,
/// because the build that needs it most is the one nobody runs from an IDE.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Read at test time so a rename of the file is a failure, not a skip.
File get _manifest => File('android/app/src/main/AndroidManifest.xml');

void main() {
  group('THE MAIN MANIFEST CARRIES WHAT A RELEASE BUILD NEEDS', () {
    test('it exists where the build expects it', () {
      expect(
        _manifest.existsSync(),
        isTrue,
        reason: 'this test is asserting about a file that must be there',
      );
    });

    test('INTERNET is declared in main, not left to the debug manifest', () {
      expect(
        _manifest.readAsStringSync(),
        contains('android.permission.INTERNET'),
        reason:
            'Flutter puts INTERNET in debug/ and profile/ only. Without it in '
            'main/, the RELEASE build has no network and fails as a DNS error '
            'while every screen still renders from cache.',
      );
    });

    test('every permission the app runs on is in main', () {
      final text = _manifest.readAsStringSync();
      // The radio the strap needs, the network the server needs, and the
      // background work that carries data between them. Each one absent is a
      // whole capability missing from release with no compile error.
      for (final permission in const <String>[
        'android.permission.INTERNET',
        'android.permission.BLUETOOTH_SCAN',
        'android.permission.BLUETOOTH_CONNECT',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.WAKE_LOCK',
      ]) {
        expect(text, contains(permission), reason: '$permission is missing');
      }
    });
  });
}
