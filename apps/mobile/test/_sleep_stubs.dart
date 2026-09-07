/// The Sleep tab's payloads, from the committed contract snapshots.
///
/// Same argument as `_today_stubs.dart`: the fixture is the repo's own
/// `packages/contracts/snapshots/sleep.json` and `sleep_consistency.json`, so a
/// server change that moves the wire fails these suites instead of leaving them
/// green against a hand-built shape that no longer exists.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_page.dart';

/// Relative to `apps/mobile` — `flutter test`'s working directory.
const String kSleepSnapshotPath =
    '../../packages/contracts/snapshots/sleep.json';

/// The regularity block's snapshot.
const String kConsistencySnapshotPath =
    '../../packages/contracts/snapshots/sleep_consistency.json';

/// The instant every night label in these suites is measured against.
///
/// The snapshot's newest night ends `2026-07-31T01:00:00+00:00`, so a clock on
/// that morning makes it "Last night" wherever the suite runs.
final DateTime kSleepNow = DateTime.parse(
  '2026-07-31T01:00:00Z',
).toLocal().add(const Duration(hours: 8));

/// One decoded snapshot.
Map<String, Object?> loadJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail(
      'Contract snapshot not found at $path (cwd ${Directory.current.path}). '
      'These tests read the repo copy on purpose — a vendored copy would go '
      'green while the wire moved.',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// The Sleep page as the server really sends it.
SleepPage sleepPageFixture() =>
    SleepPage.fromJson(loadJson(kSleepSnapshotPath));

/// The regularity block as the server really sends it.
SleepConsistency consistencyFixture() =>
    SleepConsistency.fromJson(loadJson(kConsistencySnapshotPath));

/// A nap the strap timed but never staged — a real and common shape.
///
/// The snapshot's nap IS staged, so this is the only way to reach the other
/// branch. Built by blanking the snapshot's own nap rather than by writing a
/// nap here, so it cannot drift from the wire in any field but the one under
/// test.
SleepNap unstagedNap() {
  final json = loadJson(kSleepSnapshotPath);
  final nap = Map<String, Object?>.from(
    (json['naps']! as List<Object?>).first! as Map<String, Object?>,
  );
  expect(
    nap['stages'],
    isA<Map<String, Object?>>(),
    reason:
        'the snapshot nap no longer carries stage totals, so blanking them '
        'proves nothing — the wire moved and this helper did not',
  );
  nap['stages'] = <String, Object?>{
    'light': 0,
    'deep': 0,
    'rem': 0,
    'awake': 0,
  };
  nap['stage_timeline'] = <Object?>[];
  return SleepNap.fromJson(nap);
}

/// The same page with [patch] applied to its newest night.
///
/// The honesty suites work by taking a field AWAY, which is the one thing a
/// fixture read from a snapshot cannot do on its own.
SleepPage sleepPageWithout(List<String> fields) {
  final json = loadJson(kSleepSnapshotPath);
  final nights = json['nights']! as List<Object?>;
  final latest = Map<String, Object?>.from(
    nights.first! as Map<String, Object?>,
  );
  for (final field in fields) {
    expect(
      latest.containsKey(field),
      isTrue,
      reason:
          '`$field` is not on the sleep snapshot, so blanking it proves '
          'nothing. The wire moved and this list did not.',
    );
    latest[field] = null;
  }
  return SleepPage.fromJson(<String, Object?>{
    ...json,
    'nights': <Object?>[latest, ...nights.skip(1)],
  });
}

/// The same page with no naps, and with the newest night's session stripped.
SleepPage sleepPageWithoutSession() {
  final json = loadJson(kSleepSnapshotPath);
  final nights = json['nights']! as List<Object?>;
  final latest = Map<String, Object?>.from(
    nights.first! as Map<String, Object?>,
  );
  for (final field in <String>['session_source', 'start_iso', 'end_iso']) {
    latest[field] = null;
  }
  return SleepPage.fromJson(<String, Object?>{
    ...json,
    'nights': <Object?>[latest, ...nights.skip(1)],
  });
}

/// One Sleep card at a real phone's width, in the light theme.
///
/// **390, not `_chart_probe.dart`'s 300.** `flutter test` loads no fonts, so
/// every glyph is a square of the font size — legacy's `7h 05m` at 27 px measures
/// 162 logical pixels here and about 85 in Inter on a phone. A card that fits
/// on every shipping handset would otherwise overflow in a test, and chasing that
/// with a `Flexible` on the hero figure would be letting the test font redesign
/// the screen.
Widget sleepCardHost(Widget card) => MaterialApp(
  theme: AppTheme.light,
  // Scrollable, because several of these cards are taller than a test's 600 px
  // viewport and a vertical overflow is not what any of them are about.
  home: Scaffold(
    body: SingleChildScrollView(
      child: Center(child: SizedBox(width: 390, child: card)),
    ),
  ),
);
