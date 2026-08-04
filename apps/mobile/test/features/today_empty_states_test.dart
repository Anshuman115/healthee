/// What each section does when it has nothing to say.
///
/// Brief §1: *"'no number' is a first-class screen state with as much care as
/// the happy path. If you design 20 beautiful cards and one sad empty state, you
/// have designed the wrong app."*
///
/// There are two right answers and the difference matters:
///
/// ```text
///   silence    a section with nothing to REPORT draws nothing at all
///   a refusal  a metric that could have had a value draws the hole and the why
/// ```
///
/// Data health, findings, the action card and the charts take the first: an
/// empty "Insights" heading over a blank card reads as breakage, and the honest
/// state is to not be there. Every metric block takes the second, because for
/// those the absence IS the news.
///
/// Each case below removes exactly one thing from the real contract snapshot, so
/// the test is against a payload the server could actually send.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';

import '../_today_stubs.dart';
import '_today_host.dart';

/// The snapshot with [key] emptied to [value].
Map<String, Object?> Function(Map<String, Object?>) without(
  String key,
  Object? value,
) => (json) => <String, Object?>{...json, key: value};

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('sections that fall silent', () {
    testWidgets('data health says nothing when every feed is fresh', (
      tester,
    ) async {
      // Everything the strap wrote has reached the server, which is the OTHER
      // half of "all is well" — a card that only watched the server's feeds
      // would look healthy on a phone whose push has been failing for a week.
      final pending = await store.pushReader.pending();
      await store.pushReader.markPushed(pending, now);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      // The fixture's feeds are all `ok`, nothing is pending, and the payload
      // came off the network — so the trust card has no claim to make.
      expect(
        find.text('Data health'),
        findsNothing,
        reason: 'silence when all is well is what makes it worth reading when '
            'it speaks',
      );
    });

    testWidgets('findings do not render an empty Insights heading', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(mutate: without('top_findings', const [])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsNothing);
      expect(find.text('In your own data'), findsNothing);
    });

    testWidgets('the action card is absent, not a spinner and not a refusal', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              // Null action = the nightly job has not warmed it. That is a
              // premium surface with nothing to say, NOT a withheld number.
              'action': null,
              'recommendations': const [],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget, reason: 'only the app bar');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the stress chart is absent when the day has no hours', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(mutate: without('today_stress_series', const [])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stress today'), findsNothing);
    });

    testWidgets('the week chart is absent when there are no nights', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(mutate: without('sleep_history_7d', const [])),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sleep'));

      expect(find.textContaining('Your last 7 nights'), findsNothing);
    });

    testWidgets('blood oxygen is absent when the strap measured none', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: without('last_sleep_extras', const <String, Object?>{}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sleep'));

      expect(find.text('Blood oxygen overnight', skipOffstage: false), findsNothing);
      expect(find.text('Through the night', skipOffstage: false), findsNothing);
    });
  });

  group('sections that refuse instead', () {
    testWidgets('a block the server omitted refuses, and admits it cannot say why', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(mutate: without('cardio_load', null)),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Cardio load'));

      // An absence we cannot explain is worse than one we can, and the copy
      // does not hide that — it does not claim the owner did anything wrong.
      expect(
        find.textContaining('the server did not say why'),
        findsOneWidget,
      );
      expect(find.text('WITHHELD'), findsWidgets);
    });

    testWidgets('a refused block keeps its title and its footprint', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(store, server: todayView(mutate: without('mvpa', null))),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Active minutes'));

      // Same title, same position. It reads as the app being careful, not as a
      // card that failed to load.
      expect(find.text('Active minutes'), findsOneWidget);
    });
  });
}
