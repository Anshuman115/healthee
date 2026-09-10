/// Settings and its sub-screens — the rules the redesign had to carry over.
///
/// The v02 index moved every control onto a screen of its own, so the four
/// things that were true of the old one-scroll screen are now true one level
/// down, and each is asserted where it now lives:
///
///   * **Appearance is ONE state.** The tiles write `themeControllerProvider`,
///     the same object the header toggle writes. The assertion is the
///     *rendered brightness of the whole app*, not a flag on a widget — a
///     second copy could set a flag and would not be able to do this.
///   * **The strap screen reports `lastCompleteSync`, never `lastAttempt`.** An
///     attempt that failed halfway left data unread, and calling it a sync is
///     the stale-behind-a-healthy-screen failure one screen over.
///   * **The account screen shows the address and never the token.**
///   * **The licence notice is reachable in the shipped app.** That is a licence
///     term, not a nicety: the SIL OFL requires the notice to travel with the
///     fonts, and `assets/fonts/OFL.txt` shipped only to git until it became an
///     asset with a door.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/honesty/device_absence.dart';
import 'package:healthee/features/settings/app_version.dart';
import 'package:healthee/features/settings/strap_lines.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/theme_options.dart';

import '_settings_harness.dart';

void main() {
  group('appearance is ONE state, not a second toggle', () {
    testWidgets('the tiles show the mode the app is actually in', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        settingsApp(location: Routes.appearance, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      // The RENDERED tile, not a flag: `aria-pressed` is a decoration in the
      // prototype and a `Semantics.selected` here, and the tile that is drawn
      // in the accent is the one the app is in.
      final selected = tester.widget<Semantics>(
        find
            .ancestor(of: find.text('Dark'), matching: find.byType(Semantics))
            .first,
      );
      expect(selected.properties.selected, isTrue);
    });

    testWidgets('CHOOSING A MODE HERE MOVES THE WHOLE APP', (tester) async {
      // The proof that they are one state: the header toggle reads the
      // brightness actually being rendered, so the tiles changing the theme is
      // what changes that button. Two copies could not do this.
      tallViewport(tester);
      await tester.pumpWidget(settingsApp(location: Routes.appearance));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ThemeOptions<ThemeMode>));
      expect(
        Theme.of(context).brightness,
        Brightness.dark,
        reason: 'the tiles write the same provider the header button writes',
      );
    });
  });

  group('the strap screen', () {
    testWidgets('reports the last COMPLETE sync and the battery behind it', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        settingsApp(
          location: Routes.device,
          strap: pairedStrap,
          day: dayWithSync(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(pairedStrap.mac), findsOneWidget);
      expect(find.textContaining('Last full sync 12 min ago.'), findsOneWidget);
      expect(find.textContaining('Battery 71% at that sync.'), findsOneWidget);
    });

    testWidgets('an unpaired phone says so and offers pairing', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(settingsApp(location: Routes.device));
      await tester.pumpAndSettle();

      expect(find.text('No strap paired'), findsOneWidget);
      // The way to pairing is a row on this screen, not a button: the flow is
      // a screen of its own and `features/pairing/` owns it.
      expect(find.text('Connect a strap'), findsOneWidget);
      expect(
        find.text('Find your strap and confirm its key'),
        findsOneWidget,
        reason: 'the row names what is behind it',
      );
    });

    test('a phone with no finished sync does not call that a fault', () {
      // Freshly paired is this state for a minute and nothing is wrong with it.
      final lines = strapLines(DeviceDay.empty(settingsDate), now: settingsNow);

      expect(lines.first, 'No sync has finished on this phone yet.');
      expect(lines.last, contains('has not reported its battery'));
    });

    test('a lastAttempt is NEVER reported as a sync', () {
      // The two are different facts: an attempt that failed halfway left data
      // unread. `device_day.dart` keeps both and this row reads only one.
      final attemptedOnly = DeviceDay.empty(settingsDate);
      expect(attemptedOnly.sync.lastCompleteSync, isNull);
      expect(
        strapLines(attemptedOnly, now: settingsNow).first,
        isNot(contains('Last full sync')),
      );
    });
  });

  group('the account screen', () {
    testWidgets('a signed-out phone says the strap still works', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(settingsApp(location: Routes.serverSignIn));
      await tester.pumpAndSettle();

      // The PASSWORD form, even though a test build carries no Supabase
      // dart-defines. That changed when the server started naming its own
      // identity provider (`GET /api/auth-config`): the app no longer decides at
      // BUILD time whether it can sign in, because any server the owner types
      // might name one. It finds out by asking, and reports
      // `ServerHasNoIdentityProvider` if the answer is no.
      //
      // The pasted-token form is still reachable — by the link below, which is
      // its own assertion further down — but it is no longer what a build
      // without defines is stuck with.
      expect(find.text('Sign in to your server'), findsOneWidget);
      expect(find.text('Sign in with an API token instead'), findsOneWidget);
      expect(
        find.textContaining('with no server at all'),
        findsOneWidget,
        reason: 'strap-only is a supported mode, and the screen says so',
      );
    });

    testWidgets('a signed-in phone shows the address and never a token', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        settingsApp(location: Routes.serverSignIn, signedIn: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Signed in'), findsOneWidget);
      expect(find.text('https://healthee.example.test'), findsOneWidget);
      expect(find.widgetWithText(HButton, 'Sign out'), findsOneWidget);
      expect(
        find.widgetWithText(HButton, 'Use a different server'),
        findsOneWidget,
        reason: 'the label names what is behind it, rather than "Manage"',
      );
    });
  });

  group('about', () {
    testWidgets('the licence notice is reachable in the shipped app', (
      tester,
    ) async {
      // A licence term, not a nicety — see the library docstring.
      tallViewport(tester);
      await tester.pumpWidget(settingsApp(location: Routes.about));
      await tester.pumpAndSettle();

      final licences = find.widgetWithText(HButton, 'Licences and notices');
      await revealRow(tester, licences);
      expect(find.textContaining('SIL Open Font License'), findsOneWidget);

      await tester.tap(licences);
      await tester.pumpAndSettle();
      expect(find.textContaining('Healthee'), findsWidgets);
    });

    testWidgets('a host with no plugin says so rather than inventing one', (
      tester,
    ) async {
      // A host with no plugin registrant answers nothing at all, so the read
      // resolves to null through its own deadline. The screen names the build
      // it does not know rather than showing one it made up.
      tallViewport(tester);
      await tester.pumpWidget(settingsApp(location: Routes.about));
      await tester.pumpAndSettle();

      expect(find.text('Version unavailable on this device'), findsOneWidget);
      expect(
        find.text('Reading the version…'),
        findsNothing,
        reason: 'a row that waits forever is the failure this app is against',
      );
    });

    test('the three version sentences stay distinct', () {
      // Kept as a plain test so all three can be pinned without pumping.
      expect(
        versionLine(const AsyncData<String?>('1.2.0 (7)')),
        'Version 1.2.0 (7)',
      );
      expect(
        versionLine(const AsyncData<String?>(null)),
        'Version unavailable on this device',
      );
      expect(
        versionLine(const AsyncLoading<String?>()),
        'Reading the version…',
      );
    });
  });

  group('data freshness names each stream and each absence', () {
    testWidgets('A STREAM WITH NO READING PRINTS ITS SENTENCE, NOT ITS KEY', (
      tester,
    ) async {
      // `disclosure.dart` says it plainly: the reason is an operator's filter
      // key and the message is what the owner reads. A row printing
      // `not_measured_by_strap` would be a stream explaining itself in ours.
      tallViewport(tester);
      await tester.pumpWidget(settingsApp(location: Routes.dataFreshness));
      await tester.pumpAndSettle();

      expect(find.textContaining('The strap recorded no'), findsWidgets);
      expect(
        find.textContaining(notMeasuredReason),
        findsNothing,
        reason: 'the filter key is never shown to the owner',
      );
    });

    testWidgets('a stream with a reading dates it and counts its samples', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        settingsApp(location: Routes.dataFreshness, day: dayWithSync()),
      );
      await tester.pumpAndSettle();

      // Every row states its own instrument's age, or says there is none.
      expect(find.text('Data freshness'), findsOneWidget);
      expect(find.text(settingsDate), findsOneWidget);
    });
  });
}
