/// The two cards Actions is made of, asked directly: what they will not draw.
///
/// Split out of `actions_v02_test.dart` at the 400-line gate (Standards section
/// 1). That suite is about the SCREEN — its order, its head, its widths — and
/// this one pumps the two cards on their own, because what matters about both is
/// a thing they refuse to draw and a refusal is easiest to pin without a payload
/// around it.
///
/// Both refusals are the same rule in two places: **draw what the server sent,
/// and nothing that stands in for what it did not.** A progress bar at zero and
/// a half-drawn before/after are each a reading the owner never gave us.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/data/challenges/challenge_progress.dart';
import 'package:healthee/features/actions/v02/challenge_card.dart';
import 'package:healthee/shared/challenge_outcome_card.dart';
import 'package:healthee/shared/v02/meters.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

void main() {
  group('THE CHALLENGE CARD DRAWS ONLY WHAT THE SERVER SENT', () {
    Challenge challenge({
      ChallengeProgress? progress,
      String status = 'active',
    }) => Challenge(
      id: 7,
      title: 'Seven days above 9,000',
      why: 'A small step up from your recent 8,200-step average.',
      status: status,
      metric: 'steps_total',
      target: 9000,
      comparator: '>=',
      cadence: 'daily',
      windowDays: 7,
      difficulty: 'moderate',
      kind: 'standard',
      citations: const <String>['steps_mortality'],
      progress: progress,
    );

    Widget host(Challenge value) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(
          children: <Widget>[ChallengeCard(challenge: value, onOpen: () {})],
        ),
      ),
    );

    testWidgets('NO PROGRESS BLOCK MEANS NO BAR — not a bar at zero', (
      tester,
    ) async {
      await tester.pumpWidget(host(challenge(status: 'suggested')));
      await tester.pumpAndSettle();

      expect(
        find.byType(ProgressTrack),
        findsNothing,
        reason:
            '"nothing has been observed" and "you are at zero" are different '
            'days, and a bar at the left edge says the second',
      );
      expect(ChallengeCard.fraction(null), isNull);
      // A suggestion is labelled as one, so a 7-day window does not read as a
      // commitment the owner never made.
      expect(find.text('Suggested · 7-day'), findsOneWidget);
    });

    testWidgets('a progress block draws the bar the server’s counts imply', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          challenge(
            progress: const ChallengeProgress(
              cadence: 'daily',
              target: 9000,
              daysLeft: 3,
              unit: 'steps',
              hitDays: 3,
              window: 7,
              protectedToday: false,
              breached: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProgressTrack), findsOneWidget);
      expect(find.text('3 of 7 days at the target'), findsOneWidget);
      // Painted geometry: the track is the CSS's 7 px and spans the card.
      final track = tester.getRect(find.byType(ProgressTrack));
      expect(track.height, ProgressTrack.height);
      expect(track.width, greaterThan(100));
    });
  });

  group('AN OUTCOME REPORTS, AND NEVER ATTRIBUTES', () {
    ChallengeOutcome outcome({double? baseline}) =>
        ChallengeOutcome.fromJson(<String, Object?>{
          'challenge_id': 7,
          'data_confidence': 'ok',
          'ended_at': '2026-07-31T00:00:00Z',
          'metric': 'steps_total',
          'status': 'completed',
          'baseline': baseline,
          'final': 8900,
          'adherence': 0.857,
          'confounds': <String, Object?>{
            'illness_days': 1,
            'concurrent_challenges': 1,
            'regression_to_mean': <String, Object?>{
              'assessed': true,
              'at_risk': false,
            },
          },
        });

    Widget host(ChallengeOutcome value) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(
          children: <Widget>[ChallengeOutcomeCard(outcome: value)],
        ),
      ),
    );

    testWidgets('the observation and the causal claim stay apart', (
      tester,
    ) async {
      await tester.pumpWidget(host(outcome(baseline: 8200)));
      await tester.pumpAndSettle();

      // The phrase, not the constant: `find.text(kObservationNote)` passes
      // against any sentence the constant is given, including one that claims
      // the challenge produced the change.
      expect(
        find.textContaining('an observation, not a proven effect'),
        findsOneWidget,
      );
      expect(
        find.textContaining('it cannot settle cause and effect'),
        findsOneWidget,
      );
      for (final verb in <String>['caused', 'because of', 'thanks to']) {
        expect(
          find.textContaining(verb),
          findsNothing,
          reason: 'an outcome reports what was observed, never what caused it',
        );
      }
      // The confounders the server named are on the surface, not behind it.
      expect(find.text('1 illness day'), findsOneWidget);
      expect(find.text('1 concurrent challenge'), findsOneWidget);
    });

    testWidgets('HALF A COMPARISON IS NOT DRAWN AS A WHOLE ONE', (
      tester,
    ) async {
      await tester.pumpWidget(host(outcome()));
      await tester.pumpAndSettle();

      expect(find.text('Before'), findsNothing);
      expect(find.text('During'), findsNothing);
      expect(find.byType(FactorBars), findsNothing);
      // The reading itself still shows: the missing end is the baseline.
      expect(find.text('8900'), findsOneWidget);
    });
  });
}
