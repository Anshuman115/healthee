/// The fitness screen: the error magnitude, the history, and the instrument.
///
/// The three claims worth a test:
///
///   * **The ± is an error MAGNITUDE and the card says it is not an interval.**
///     A reader who takes a published model error for a confidence interval has
///     mis-read the uncertainty of the number in front of them, and that
///     sentence is the only thing stopping them. `test/mutations.sh` breaks it.
///   * **The stored history cannot tell a method change from a fitness change**,
///     because `trend_90d` carries no method. The note says so; without it the
///     line implies a continuity the payload cannot support.
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

  testWidgets('THE HISTORY SAYS A METHOD CHANGE CANNOT BE TOLD APART', (
    tester,
  ) async {
    tallViewport(tester);
    await tester.pumpWidget(
      todayHost(store, server: todayView(), home: const FitnessScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text(StoredHistoryPanel.title), findsOneWidget);
    expect(find.byType(V02LineChart), findsOneWidget);
    expect(find.textContaining(kStoredHistoryNote), findsOneWidget);
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
