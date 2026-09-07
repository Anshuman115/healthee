/// The host both workout suites pump, and the payloads they read.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
///
/// The two screens read three providers between them and every one of them
/// reaches a socket if it is left alone:
///
///   * `workoutHistoryProvider` — `/api/activity`, for the session list.
///   * `workoutDetailProvider` — `/api/activity/workout`, for one session.
///   * `todaySnapshotProvider` — `/api/today`, which carries the strength block
///     the list's last card borrows.
///
/// ## The payloads are the committed contract snapshots
///
/// `packages/contracts/snapshots/workout.json` and `activity.json`, read out of
/// the repo rather than vendored here, for the reason `_today_stubs.dart`
/// records: a hand-built fixture goes green while the wire moves. [mutateWorkout]
/// is how a suite asks "what does the screen do when the server sent no HRmax?"
/// — by taking the field off the real payload, not by inventing a smaller one.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/data/workouts/workout_detail.dart';
import 'package:healthee/data/workouts/workout_repository.dart';
import 'package:healthee/data/workouts/workout_summary.dart';

import '../_today_stubs.dart';

/// The workout snapshot, relative to `apps/mobile` — `flutter test`'s cwd.
const String kWorkoutPath = '../../packages/contracts/snapshots/workout.json';

/// The activity snapshot, whose `workouts` array is the list screen's payload.
const String kActivityPath = '../../packages/contracts/snapshots/activity.json';

/// The fixture session's start, as the route carries it.
const String kWorkoutStart = '2026-07-31T01:30:00+00:00';

/// A JSON snapshot from the repo, decoded.
Map<String, Object?> loadSnapshot(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail(
      'Contract snapshot not found at $path (cwd ${Directory.current.path}). '
      'These suites read the repo copy on purpose — a vendored copy would go '
      'green while the wire moved.',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// The fixture session, with [mutate] applied to its JSON first.
WorkoutDetail workoutFixture({
  Map<String, Object?> Function(Map<String, Object?> json)? mutate,
}) {
  final json = loadSnapshot(kWorkoutPath);
  return WorkoutDetail.fromJson(mutate == null ? json : mutate(json));
}

/// The activity payload's session list, with [mutate] applied first.
List<WorkoutSummary> sessionsFixture({
  Map<String, Object?> Function(Map<String, Object?> json)? mutate,
}) {
  final json = loadSnapshot(kActivityPath);
  final applied = mutate == null ? json : mutate(json);
  return <WorkoutSummary>[
    for (final item in applied['workouts']! as List<Object?>)
      WorkoutSummary.fromJson(item! as Map<String, Object?>),
  ];
}

/// Drops `hrmax`, so the zones have nothing to be cut against.
Map<String, Object?> withoutHrmax(Map<String, Object?> json) =>
    <String, Object?>{...json, 'hrmax': null};

/// Empties `hr_series`, the state a session is in before its minutes upload.
Map<String, Object?> withoutSamples(Map<String, Object?> json) =>
    <String, Object?>{...json, 'hr_series': const <Object?>[]};

/// Drops one derived metric, the way the server omits one whose inputs failed.
Map<String, Object?> Function(Map<String, Object?>) withoutMetric(String key) =>
    (json) => <String, Object?>{
      ...json,
      'metrics': <String, Object?>{
        ...json['metrics']! as Map<String, Object?>,
      }..remove(key),
    };

/// Removes the minutes in `[from, to)` from `hr_series`, leaving a real hole.
Map<String, Object?> Function(Map<String, Object?>) withGap(int from, int to) =>
    (json) => <String, Object?>{
      ...json,
      'hr_series': <Object?>[
        for (final item in json['hr_series']! as List<Object?>)
          if (((item! as Map<String, Object?>)['min']! as num).toInt() < from ||
              ((item as Map<String, Object?>)['min']! as num).toInt() >= to)
            item,
      ],
    };

/// Keeps only the first [count] heart-rate samples.
Map<String, Object?> Function(Map<String, Object?>) firstSamples(int count) =>
    (json) => <String, Object?>{
      ...json,
      'hr_series': (json['hr_series']! as List<Object?>).take(count).toList(),
    };

/// One workout screen, with every provider it reads pinned.
///
/// A null [view] leaves `/api/today` unreachable — which is what the detail
/// screen always sees, and what the list screen must survive with no strength
/// card rather than with an error card for somebody else's payload.
Widget workoutsHost(
  Widget home, {
  List<WorkoutSummary>? sessions,
  WorkoutDetail? detail,
  TodayView? view,
  double width = 390,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      workoutHistoryProvider.overrideWith(
        (ref) async => sessions ?? sessionsFixture(),
      ),
      workoutDetailProvider(
        kWorkoutStart,
      ).overrideWith((ref) async => detail ?? workoutFixture()),
      todaySnapshotProvider.overrideWith(
        view == null ? todayUnreachable() : todayIs(view),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: home),
      ),
    ),
  );
}
