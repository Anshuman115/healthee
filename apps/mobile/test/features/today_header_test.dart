/// The editorial head of Today: the date row, the greeting, and the tab bar.
///
/// The test that matters most here is the one about what the greeting does NOT
/// say. Legacy tints a fragment of its opening sentence — "You're **well
/// recovered** —" — and the obvious way to reproduce that is to derive a phrase
/// from `recovery_score.band`. The contract snapshot is exactly the case that
/// makes it a bug: `band: "high"` sitting beside guidance that begins "An
/// illness signal is active". A cheerful phrase beside a safety message is the
/// flattery this product exists not to do, so the sentence renders verbatim and
/// nothing is highlighted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/theme_controller.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/widgets/greeting_block.dart';
import 'package:healthee/features/today/widgets/today_header.dart';
import 'package:healthee/features/today/widgets/today_tab_bar.dart';

import '_today_host.dart';

/// One widget in the light theme, with a provider scope for the toggle.
Widget host(Widget child) => ProviderScope(
  child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
);

void main() {
  group('the date eyebrow', () {
    testWidgets('spells the day out, as legacy does', (tester) async {
      await tester.pumpWidget(host(TodayHeader(now: DateTime(2026, 8, 6))));
      await tester.pumpAndSettle();

      expect(find.text('THURSDAY, AUGUST 6'), findsOneWidget);
    });

    test('every weekday and month has a name', () {
      // Off-by-one in a hand-rolled name table is the classic version of this
      // bug, and it only shows on one day of the week.
      expect(longDateLabel(DateTime(2026, 1, 5)), 'Monday, January 5');
      expect(longDateLabel(DateTime(2026, 12, 27)), 'Sunday, December 27');
    });
  });

  group('the greeting', () {
    test('follows the clock, and the small hours are not "morning"', () {
      expect(greetingFor(DateTime(2026, 8, 4, 2)), 'Still up.');
      expect(greetingFor(DateTime(2026, 8, 4, 9)), 'Good morning.');
      expect(greetingFor(DateTime(2026, 8, 4, 14)), 'Good afternoon.');
      expect(greetingFor(DateTime(2026, 8, 4, 21)), 'Good evening.');
    });

    testWidgets('renders the server sentence verbatim', (tester) async {
      const guidance = 'Keep today easy and skip anything hard.';
      await tester.pumpWidget(
        host(const GreetingBlock(guidance: guidance)),
      );
      await tester.pumpAndSettle();

      expect(find.text(guidance), findsOneWidget);
    });

    testWidgets('says nothing extra when the server sent no recovery block', (
      tester,
    ) async {
      await tester.pumpWidget(host(GreetingBlock(now: DateTime(2026, 8, 4, 9))));
      await tester.pumpAndSettle();

      expect(find.text('Good morning.'), findsOneWidget);
      // No invented sentence in place of one we do not have.
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('the greeting beside an overridden guidance', () {
    late LocalStore store;

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });
    tearDown(() async => store.close());

    testWidgets('NO CHEERFUL PHRASE SITS BESIDE THE ILLNESS SENTENCE', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      // The fixture's band is `high` and its guidance is the illness override.
      expect(
        find.textContaining('An illness signal is active'),
        findsOneWidget,
      );
      for (final flattery in <String>[
        'Well recovered',
        'well recovered',
        'Primed',
        'PRIMED',
        'Ready to train',
      ]) {
        expect(
          find.textContaining(flattery),
          findsNothing,
          reason: 'the band is not a phrase, and the flag overrides the day',
        );
      }
    });
  });

  group('the theme toggle', () {
    testWidgets('asks for the opposite of what is on screen', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // The controller is auto-disposed, and the header only ever `read`s it —
      // `app.dart` is what watches it in the real tree. Without a listener here
      // the notifier is thrown away the instant the tap returns and the state
      // reads back as `system`, which looks exactly like a toggle that does
      // nothing.
      final subscription = container.listen(themeControllerProvider, (_, _) {});
      addTearDown(subscription.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: TodayHeader(now: DateTime(2026, 8, 4))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on `system`, so the first tap has to decide from the brightness
      // actually being rendered rather than from the stored mode.
      expect(container.read(themeControllerProvider), ThemeMode.system);
      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();
      expect(container.read(themeControllerProvider), ThemeMode.dark);
    });
  });

  group('the tab bar', () {
    testWidgets('shows all five tabs', (tester) async {
      await tester.pumpWidget(host(const TodayTabBar()));
      await tester.pumpAndSettle();

      for (final tab in kTodayTabs) {
        expect(find.text(tab.label), findsOneWidget);
      }
    });

    test('ONLY THE TABS WITH SCREENS ARE MARKED BUILT', () {
      // `core/router.dart`: "a route with no screen would be a link to a crash".
      // The day Sleep ships, this list and that router move together.
      expect(kTodayTabs.where((tab) => tab.built).map((tab) => tab.label), ['Today']);
    });

    testWidgets('an unbuilt tab is disabled to a screen reader, not just dim', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const TodayTabBar()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Sleep — not built yet'), findsOneWidget);
      expect(find.bySemanticsLabel('Today'), findsOneWidget);
      handle.dispose();
    });
  });
}
