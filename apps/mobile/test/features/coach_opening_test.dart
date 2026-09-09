/// The opener is the coach speaking unasked, and the rules are about that.
///
/// It replaced a headline that took a third of the screen and said nothing. The
/// risk in replacing filler with CONTENT is the opposite failure: content that
/// invents itself when there is none, or that reads like an answer the owner paid
/// for. These pin both.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/features/coach/v02/coach_opening.dart';

Future<void> _pump(WidgetTester tester, String? line, {bool pending = false}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoachOpening(line: line, pending: pending),
          ),
        ),
      ),
    );

void main() {
  group('silence, never a placeholder', () {
    testWidgets('null on a NON-entitled account draws nothing at all', (
      tester,
    ) async {
      // Null is the ordinary state on a free account (the AI gate strips the
      // field), on any day but today (the cache is keyed to the owner's current
      // day), and before the nightly chain has run. Inventing a line to fill the
      // space is exactly what the block this replaced was guilty of.
      await _pump(tester, null);

      expect(find.text(kCoachOpeningLabel), findsNothing);
      expect(find.text(kCoachOpeningPending), findsNothing);
    });

    testWidgets('an entitled owner with no line yet is told WHEN, not sorry', (
      tester,
    ) async {
      // Observed on the device at 08:20: the night had arrived, the chain fires
      // at 10:30, and `kv` held yesterday's line — so the field was correctly
      // null and the screen showed a blank band. Nothing was broken; it simply
      // refused to explain itself.
      await _pump(tester, null, pending: true);

      expect(find.text(kCoachOpeningPending), findsOneWidget);
      expect(kCoachOpeningPending, contains('each morning'));
      expect(kCoachOpeningPending, contains('synced'));
    });

    testWidgets('an empty or blank line draws nothing either', (tester) async {
      await _pump(tester, '   ');

      expect(find.text(kCoachOpeningLabel), findsNothing);
    });
  });

  group('when there is a line', () {
    const String line =
        'Your recovery is 83 against a median of 58, and your sleep debt is '
        'near 29 hours.';

    testWidgets('it is shown verbatim under a caption naming whose it is', (
      tester,
    ) async {
      await _pump(tester, line);

      expect(find.text(line), findsOneWidget);
      expect(find.text(kCoachOpeningLabel), findsOneWidget);
    });

    testWidgets('the note ids are rendered, never printed raw', (tester) async {
      // THE regression. The first build used a plain `Text`, so the server's
      // inline markers reached the screen as literal brackets in the middle of a
      // sentence — "…signal under-recovery [resting_heart_rate,
      // recovery_readiness]." — which is the wire format leaking into the UI.
      // Every other grounded surface in this app renders these, including the
      // coach's own replies.
      await _pump(
        tester,
        'Keep today easy, as your resting heart rate is elevated '
        '[resting_heart_rate, recovery_readiness].',
      );

      expect(find.textContaining('[resting_heart_rate'), findsNothing);
      expect(find.textContaining('recovery_readiness]'), findsNothing);
    });

    testWidgets('the caption dates it, so it cannot read as a fresh answer', (
      tester,
    ) async {
      // The one thing this must never be mistaken for is a reply to a question
      // the owner asked and was charged for. The caption says when it was said
      // and that the coach said it, unprompted.
      await _pump(tester, line);

      expect(kCoachOpeningLabel.toUpperCase(), kCoachOpeningLabel);
      expect(kCoachOpeningLabel, contains('THIS MORNING'));
      expect(kCoachOpeningLabel, contains('COACH'));
    });
  });
}
