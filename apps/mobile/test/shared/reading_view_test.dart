/// Widget smoke tests: the app boots, both themes build, and each honesty state
/// renders something a person could act on.
///
/// The last clause is the one that matters. "It rendered" is not the bar — the
/// bar is that a withheld value shows its remedy and an error shows its retry,
/// because a state that renders as a blank card is exactly the bug Standards §3
/// names.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/app.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/theme_controller.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/data/updates/update_check.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

import '../_today_stubs.dart';

const Disclosure _weightStale = Disclosure(
  reason: 'logged_weight_stale',
  message: 'Log a new weight and this comes straight back.',
  asOfDate: '2026-06-04',
  ageDays: 61,
);

Widget _host(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Widget _label(BuildContext context, String value) => Text(value);

void main() {
  group('the app shell', () {
    // `pump`, never `pumpAndSettle`: the specimen sheet includes a LoadingState,
    // and a CircularProgressIndicator animates forever — pumpAndSettle would wait
    // for a frame that never comes. Any screen showing a spinner has this
    // property, so the rule generalises to the real screens.
    testWidgets('boots onto Today, not onto the specimen sheet', (tester) async {
      // `/` used to render `FoundationScreen`, whose loading specimen the owner
      // reasonably read as a hung request. The home route is the product now,
      // and the catalogue is only reachable by typing its dev path.
      final store = LocalStore.memory();
      addTearDown(store.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStoreProvider.overrideWithValue(store),
            todaySnapshotProvider.overrideWith(todayUnreachable()),
      // The update check is a real GitHub request, started by `UpdateWatcher` on
      // the app frame. Left live it outlives the test as a pending Dio timer —
      // "A Timer is still pending even after the widget tree was disposed",
      // which names nothing about updates and sends you looking at the screen
      // under test. Unknown is the honest stub: it is what an offline phone
      // gets, and it opens no sheet.
      updateStatusProvider.overrideWith((ref) async => const UpdateUnknown()),
          ],
          child: const HealtheeApp(),
        ),
      );
      await tester.pump();

      // Two of them since the v02 redesign: the tab bar's label, and the
      // screen's own h1. Both are Today, which is the claim.
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Foundation — the four honesty states'), findsNothing);
    });

    testWidgets('builds in dark mode too — both themes are authored', (tester) async {
      final store = LocalStore.memory();
      addTearDown(store.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeControllerProvider.overrideWith(_AlwaysDark.new),
            localStoreProvider.overrideWithValue(store),
            todaySnapshotProvider.overrideWith(todayUnreachable()),
      // The update check is a real GitHub request, started by `UpdateWatcher` on
      // the app frame. Left live it outlives the test as a pending Dio timer —
      // "A Timer is still pending even after the widget tree was disposed",
      // which names nothing about updates and sends you looking at the screen
      // under test. Unknown is the honest stub: it is what an offline phone
      // gets, and it opens no sheet.
      updateStatusProvider.overrideWith((ref) async => const UpdateUnknown()),
          ],
          child: const HealtheeApp(),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      // The token set must resolve, not fall back — `context.colors` throws
      // rather than inventing a palette, so reaching it at all is the assertion.
      expect(context.colors.bg, const HealtheeColors.dark().bg);
      // The accent is a PAIR, not one value reused. If someone reinstates a
      // theme-invariant brand colour, this is the test that catches it.
      expect(context.colors.accent, const HealtheeColors.dark().accent);
      expect(
        context.colors.accent,
        isNot(const HealtheeColors.light().accent),
        reason: 'light and dark accents are independently chosen',
      );
    });
  });

  group('ReadingView renders every state usefully', () {
    testWidgets('Present shows the value and nothing else', (tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingView<String>(
            reading: Present<String>('43.0'),
            label: 'VO₂max',
            builder: _label,
          ),
        ),
      );

      expect(find.text('43.0'), findsOneWidget);
      expect(find.text('WITHHELD'), findsNothing);
      expect(find.byType(ValueHole), findsNothing);
    });

    testWidgets('Caveated shows the value AND says it is caveated, unasked', (
      tester,
    ) async {
      // "A caveat only the database can see is the same silence somewhere new."
      // The caller passed no caveatBuilder; the disclosure must appear anyway.
      //
      // What appears changed on 2026-08-06 — the signpost, not the essay. The
      // prose is one tap behind it (asserted below), because printing four
      // server disclosures in full put ~2,780 characters under Today's
      // biological-age card.
      await tester.pumpWidget(
        _host(
          const ReadingView<String>(
            reading: Caveated<String>('34.3', [
              Disclosure(reason: 'fitness_estimated', message: 'The fitness term is estimated.'),
            ]),
            label: 'Biological age',
            builder: _label,
          ),
        ),
      );

      expect(find.text('34.3'), findsOneWidget);
      expect(find.text(caveatHeadline(1)), findsOneWidget);
      // Compact means compact: the prose is NOT on the card.
      expect(find.text('The fitness term is estimated.'), findsNothing);
    });

    testWidgets('THE CAVEAT DETAIL IS REACHABLE — one tap, in full', (
      tester,
    ) async {
      // The half that makes the compaction honest. A signpost pointing at
      // nothing is worse than the essay it replaced.
      await tester.pumpWidget(
        _host(
          const ReadingView<String>(
            reading: Caveated<String>('34.3', [
              Disclosure(reason: 'fitness_estimated', message: 'The fitness term is estimated.'),
              Disclosure(
                reason: 'sleep_scaled',
                message: 'Your sleep hours are translated first.',
                term: 'sleep duration',
              ),
            ]),
            label: 'Biological age',
            builder: _label,
          ),
        ),
      );

      expect(find.text(caveatHeadline(2)), findsOneWidget);
      await tester.tap(find.text(caveatHeadline(2)));
      await tester.pumpAndSettle();

      expect(find.text(kCaveatSheetTitle), findsOneWidget);
      // EVERY disclosure, in the server's own words — not the first one only.
      expect(find.text('The fitness term is estimated.'), findsOneWidget);
      expect(find.text('Your sleep hours are translated first.'), findsOneWidget);
      // And the term that scopes the second one.
      expect(find.text('SLEEP DURATION'), findsOneWidget);
    });

    testWidgets('THE COUNT IS ON THE SCREEN — a dropped disclosure shows', (
      tester,
    ) async {
      // Why the headline counts rather than just naming the state: it is the
      // only part of a compacted caveat a reader sees without tapping, so it is
      // where a disclosure going missing has to become visible.
      expect(caveatHeadline(1), isNot(caveatHeadline(2)));
      expect(caveatHeadline(3), contains('3'));
      expect(caveatHeadline(4), contains('4'));
    });

    testWidgets('Withheld keeps the number-shaped hole, the label and the remedy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ReadingView<String>(
            reading: Withheld<String>(_weightStale),
            label: 'VO₂max',
            builder: _label,
          ),
        ),
      );

      // Brief §3: "a card with a number-shaped hole, not a card that failed to
      // load. Same footprint, same title, same position."
      expect(find.byType(ValueHole), findsOneWidget);
      expect(find.text('WITHHELD'), findsOneWidget);
      expect(find.text('VO₂max'), findsOneWidget);
      // The remedy — the load-bearing half of the block.
      expect(find.text('Log a new weight and this comes straight back.'), findsOneWidget);
      // Dated history, in faint small type — never where a reading would be.
      expect(find.text('Last reading 2026-06-04 — 61 days ago'), findsOneWidget);
      // A withhold is an answer, not a failure. Offering "Try again" would
      // invite the owner to re-ask a question we have already answered.
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('Withheld shows the explainer pill only when one can open', (tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingView<String>(
            reading: Withheld<String>(_weightStale),
            builder: _label,
          ),
        ),
      );
      // No sheet to open: no dead affordance.
      expect(find.text('What would restore it'), findsNothing);

      var opened = 0;
      await tester.pumpWidget(
        _host(
          ReadingView<String>(
            reading: const Withheld<String>(_weightStale),
            builder: _label,
            onExplainWithheld: () => opened++,
          ),
        ),
      );

      expect(find.text('What would restore it'), findsOneWidget);
      await tester.tap(find.text('What would restore it'));
      expect(opened, 1);
      // Still not a retry — it opens the reasoning, it does not re-ask.
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('Withheld never renders the raw reason id at a person', (tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingView<String>(
            reading: Withheld<String>(_weightStale),
            builder: _label,
          ),
        ),
      );

      expect(find.text('logged_weight_stale'), findsNothing);
    });

    testWidgets('Excluded explains, and offers nothing to do', (tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingView<String>(
            reading: Excluded<String>([
              Disclosure(
                reason: 'sri_hazard_not_transportable',
                message: 'We cannot honestly convert regularity into years.',
                term: 'regularity',
              ),
            ]),
            label: 'Biological age',
            builder: _label,
          ),
        ),
      );

      // The FACT stays on the card, naming the term. The reasoning is one tap
      // behind it — the same trade `CaveatNote` made, for the same report.
      expect(find.text('Left out of this number: regularity'), findsOneWidget);
      expect(
        find.text('We cannot honestly convert regularity into years.'),
        findsNothing,
        reason: 'the essay inline is the defect; the signpost is the fix',
      );
      expect(find.text('Try again'), findsNothing);

      await tester.tap(find.text('READ'));
      await tester.pumpAndSettle();
      expect(
        find.text('We cannot honestly convert regularity into years.'),
        findsOneWidget,
        reason:
            'an exclusion whose reasoning became unreachable is a regression, '
            'not a tidy-up',
      );
      expect(find.text(kExclusionSheetTitle), findsOneWidget);
    });
  });

  group('the shared async states', () {
    testWidgets('an error always carries a working retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _host(
          ErrorState(
            message: "Couldn't reach the server",
            detail: 'This is a connection problem.',
            onRetry: () => retried++,
          ),
        ),
      );

      expect(find.text("Couldn't reach the server"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('an empty state says what is missing AND how to fill it', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            message: 'No workouts this week',
            hint: 'Recorded sessions appear here after a sync.',
          ),
        ),
      );

      expect(find.text('No workouts this week'), findsOneWidget);
      expect(find.text('Recorded sessions appear here after a sync.'), findsOneWidget);
    });

    testWidgets('loading names what it is loading', (tester) async {
      await tester.pumpWidget(_host(const LoadingState(label: 'Loading today')));
      expect(find.text('Loading today'), findsOneWidget);
    });
  });
}

class _AlwaysDark extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.dark;
}
