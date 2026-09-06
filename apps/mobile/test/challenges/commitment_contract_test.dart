import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/challenges/challenge_feed.dart';
import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/data/challenges/program_feed.dart';
import 'package:healthee/data/insights/generated_insight.dart';
import 'package:healthee/data/profile/health_profile.dart';
import 'package:healthee/data/workouts/workout_detail.dart';

Map<String, Object?> snapshot(String name) =>
    jsonDecode(
          File(
            '../../packages/contracts/snapshots/$name.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

void main() {
  test(
    'profile calendar date is restored without converting the legacy instant',
    () {
      final profile = HealthProfile.fromJson(snapshot('profile'));
      expect(profile.dobDate, '1990-05-01');
      expect(profile.weightKg, 72.5);
      expect(profile.weightAsOf, '2026-07-31');
      final legacy = HealthProfile.fromJson({'dob': 641500200000});
      expect(legacy.dobDate, isNull);
      expect(legacy.legacyBirthdayPresent, isTrue);
    },
  );
  test('workout summary, HR offsets, zones and TRIMP match server fixture', () {
    final detail = WorkoutDetail.fromJson(snapshot('workout'));
    expect(detail.workout.sportName, 'Outdoor run');
    expect(detail.workout.durationMin, 30);
    expect(detail.heartRate.first.at, detail.workout.start);
    expect(detail.zones, [0, 9, 17, 2, 0]);
    expect(detail.trimp, 36.9);
  });
  test(
    'challenge progress and reduced steps preserve canonical server states',
    () {
      final feed = ChallengeFeed.fromJson(snapshot('challenges'));
      expect(feed.active.first.progress!.todayValue, 8200);
      expect(feed.active.first.progress!.hitDays, 0);
      expect(
        feed.active.any((challenge) => challenge.kind == 'deload'),
        isTrue,
      );
      expect(feed.find(feed.active.first.id), same(feed.active.first));
      expect(feed.find(-1), isNull);
    },
  );
  test('program feed parses active ladder and rungs', () {
    final feed = ProgramFeed.fromJson(snapshot('programs'));
    expect(feed.active, isNotNull);
    expect(feed.active!.rungs, isNotEmpty);
    expect(feed.find(feed.active!.id), same(feed.active));
  });
  test('outcome confidence and confounders accompany changes', () {
    final rows = snapshot('challenge_outcomes')['outcomes']! as List<Object?>;
    final result = ChallengeOutcome.fromJson(
      rows.first! as Map<String, Object?>,
    );
    expect(result.adherence, 0.857);
    expect(result.illnessDays, 1);
    expect(result.concurrentChallenges, 1);
    expect(result.regressionRisk, isFalse);
    expect(result.coOccurrenceNote, contains('not attributed'));
  });
  test(
    'unvalidated generated claims are withheld while refusals remain visible',
    () {
      expect(
        GeneratedInsight.fromJson({
          'insight': 'Unsafe assertion',
          'validated': false,
        }).text,
        isEmpty,
      );
      expect(
        GeneratedInsight.fromJson({
          'insight': 'Cannot infer that',
          'refused': true,
        }).text,
        'Cannot infer that',
      );
      expect(
        GeneratedInsight.fromJson({
          'insight': 'Grounded [note]',
          'validated': true,
          'citations': ['note'],
        }).citations,
        ['note'],
      );
    },
  );
}
