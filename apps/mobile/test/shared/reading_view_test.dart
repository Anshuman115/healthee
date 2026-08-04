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
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

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
    testWidgets('boots and renders the foundation screen', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: HealtheeApp()));
      await tester.pump();

      expect(find.text('Healthee'), findsOneWidget);
      expect(find.text('Foundation — the four honesty states'), findsOneWidget);
    });

    testWidgets('builds in dark mode too — both themes are authored', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [themeControllerProvider.overrideWith(_AlwaysDark.new)],
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

    testWidgets('Caveated shows the value AND its caveat, unasked', (tester) async {
      // "A caveat only the database can see is the same silence somewhere new."
      // The caller passed no caveatBuilder; the disclosure must appear anyway.
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
      expect(find.text('The fitness term is estimated.'), findsOneWidget);
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

      expect(find.text('Left out: regularity'), findsOneWidget);
      expect(find.text('We cannot honestly convert regularity into years.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
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
