/// The fitness screen: the error magnitude, the history, and the instrument.
///
/// The three claims worth a test:
///
///   * **The ± is an error MAGNITUDE and the card says it is not an interval.**
///     A reader who takes a published model error for a confidence interval has
///     mis-read the uncertainty of the number in front of them, and that
///     sentence is the only thing stopping them. `test/mutations.sh` breaks it.
///   * **The stored history names the instrument that read each point.**
///     `trend_90d` carried no method and the note said a method change could not
///     be told from a fitness change; it carries one now
///     (`docs/BACKEND_GAPS_FROM_UI.md` B2) and the note answers the question
///     instead of warning that it could not be answered. Three endings, because
///     "the wire said nothing", "one instrument throughout" and "more than one"
///     are three different facts about the window.
///   * **The instrument panel draws the fit, not the estimate again** — R² and
///     the fitted speed — and is absent entirely when no session produced the
///     number.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/activity/fitness_screen.dart';
import 'package:healthee/features/activity/v02/fitness_effort_panels.dart';
import 'package:healthee/features/activity/v02/fitness_panels.dart';
import 'package:healthee/shared/charts/v02/v02_line_chart.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../_today_stubs.dart';
import '_settings_harness.dart' show tallViewport;
import '_today_host.dart';

/// The payload with `submax` taken away — a Jurca-tier estimate.
Map<String, Object?> _withoutSubmax(Map<String, Object?> json) =>
    <String, Object?>{
      ...json,
      'vo2max': <String, Object?>{
        ...json['vo2max']! as Map<String, Object?>,
        'submax': null,
      },
    };

/// The snapshot's own VO2max block with [trend] swapped in.
///
/// Built off the wire rather than hand-constructed, so the only thing that
/// differs between the three cases below is the field under test.
Vo2max _vo2maxWith(List<Map<String, Object?>> trend) {
  final block = Map<String, Object?>.from(
    loadTodayJson()['vo2max']! as Map<String, Object?>,
  );
  block['trend_90d'] = trend;
  final parsed = Vo2max.maybe(block);
  expect(parsed, isNotNull, reason: 'the snapshot no longer carries a VO2max');
  return parsed!;
}

/// A trend where each point names [methods] — null for a point the wire did not
/// label, which is the shape an older server sends.
List<Map<String, Object?>> _trend(List<String?> methods) =>
    <Map<String, Object?>>[
      for (var i = 0; i < methods.length; i++)
        <String, Object?>{
          'date': '2026-07-${(i + 1).toString().padLeft(2, '0')}',
          'value': 41.0 + i,
          if (methods[i] case final String method) 'method': method,
        },
    ];

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() => store.close());

  testWidgets('THE BAND IS NAMED AS AN ERROR MAGNITUDE, NOT AN INTERVAL', (
    tester,
  ) async {
    tallViewport(tester);
    await tester.pumpWidget(
      todayHost(store, server: todayView(), home: const FitnessScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(CardiorespiratoryPanel.title), findsOneWidget);
    expect(
      find.textContaining('Supplied error magnitude: ±2.95 ml/kg/min'),
      findsOneWidget,
    );
    expect(
      find.textContaining('The band is not a confidence interval.'),
      findsWidgets,
    );
  });

  test('the sentence names the source the server supplied', () {
    final vo2max = Vo2max.maybe(
      loadTodayJson()['vo2max']! as Map<String, Object?>,
    )!;
    final note = CardiorespiratoryPanel.errorNote(vo2max)!;
    expect(note, contains('derived from Carrier 2023'));
    // No magnitude, no sentence — never a ± the payload did not send.
    expect(
      CardiorespiratoryPanel.errorNote(
        Vo2max.maybe(<String, Object?>{
          ...loadTodayJson()['vo2max']! as Map<String, Object?>,
          'see_ml_kg_min': null,
        })!,
      ),
      isNull,
    );
  });

  testWidgets('THE HISTORY NAMES WHAT READ EACH POINT, OR SAYS IT WAS NOT TOLD', (
    tester,
  ) async {
    tallViewport(tester);
    await tester.pumpWidget(
      todayHost(store, server: todayView(), home: const FitnessScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(StoredHistoryPanel.title), findsOneWidget);
    expect(find.byType(V02LineChart), findsOneWidget);
    // The contract snapshot's window really does cross two instruments — a
    // graded fit and Jurca — so this is the mixed ending, and it is the case the
    // old caveat could only warn about in the abstract. The unlabelled sentence
    // must be GONE: it says the wire did not tell us, and the wire did.
    expect(find.textContaining(kMixedMethodNote), findsOneWidget);
    expect(find.textContaining(kStoredHistoryNote), findsNothing);
  });

  test('the three endings are three different facts about the window', () {
    // A window nobody labelled is not a window read one way throughout, and
    // collapsing the two would be the caveat disappearing rather than being
    // answered.
    String noteFor(List<Map<String, Object?>> trend) => StoredHistoryPanel(
      vo2max: _vo2maxWith(trend),
      reveals: RevealRegistry(),
    ).note;

    expect(
      noteFor(_trend(<String?>[null, null])),
      contains(kStoredHistoryNote),
    );
    expect(
      noteFor(_trend(<String?>['jurca_non_exercise', 'jurca_non_exercise'])),
      contains(kSingleMethodNote),
    );
    expect(
      noteFor(_trend(<String?>['jurca_non_exercise', 'gps_graded'])),
      contains(kMixedMethodNote),
    );
  });

  group('the instrument panel', () {
    testWidgets('draws the FIT — R² and the fitted speed', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(
        todayHost(store, server: todayView(), home: const FitnessScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text(InstrumentPanel.title), findsOneWidget);
      expect(find.text('Session fit · R²'), findsOneWidget);
      expect(find.text('0.82'), findsOneWidget);
      expect(find.text('Last fitted speed'), findsOneWidget);
      expect(find.text('8.1'), findsOneWidget);
    });

    testWidgets('is ABSENT when no session produced the estimate', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(mutate: _withoutSubmax),
          home: const FitnessScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // The estimate is still drawn — only the claim about a session is gone.
      expect(find.text(CardiorespiratoryPanel.title), findsOneWidget);
      expect(find.text(InstrumentPanel.title), findsNothing);
    });
  });

  testWidgets('the work and the rhythm close the screen', (tester) async {
    tallViewport(tester);
    await tester.pumpWidget(
      todayHost(store, server: todayView(), home: const FitnessScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(WorkPanel.title), findsOneWidget);
    expect(find.text(kWorkNote), findsOneWidget);
    expect(find.text(RhythmPanel.title), findsOneWidget);
    expect(find.text(kRhythmNote), findsOneWidget);
  });
}
