/// Overrides that keep a widget test off the network, and the golden payload.
///
/// `TodayScreen` watches `/api/today`, so any test that pumps it will otherwise
/// reach for a socket, hang on a connect timeout, and fail as "pumpAndSettle
/// timed out" — a message that says nothing about the real cause. Every host
/// here overrides the provider itself rather than faking a transport: what these
/// suites are about is what the SCREEN does with a payload, and a real dio in
/// the middle only adds a timer to leak.
///
/// The payload is the committed contract snapshot, read from the repo. A
/// hand-built fixture would drift from the wire the moment the server moved, and
/// this test file's whole value is that it cannot.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/models/today_view.dart';

/// The snapshot, relative to `apps/mobile` — `flutter test`'s working directory.
const String kSnapshotPath = '../../packages/contracts/snapshots/today.json';

/// When the fixture payload was received, for the freshness labels.
final DateTime kFetchedAt = DateTime(2026, 8, 4, 9, 20);

/// The committed contract snapshot, decoded.
Map<String, Object?> loadTodayJson() {
  final file = File(kSnapshotPath);
  if (!file.existsSync()) {
    fail(
      'Contract snapshot not found at $kSnapshotPath '
      '(cwd ${Directory.current.path}). These tests read the repo copy on '
      'purpose — a vendored copy would go green while the wire moved.',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// The snapshot as the screen receives it, with [mutate] applied to the JSON.
///
/// [mutate] is how a test asks "what does the screen do when the server withheld
/// this?" without hand-building a payload around the change.
TodayView todayView({
  Map<String, Object?> Function(Map<String, Object?> json)? mutate,
  bool fromCache = false,
  DateTime? fetchedAt,
}) {
  final json = loadTodayJson();
  return TodayView(
    snapshot: TodaySnapshot.fromJson(mutate == null ? json : mutate(json)),
    fetchedAt: fetchedAt ?? kFetchedAt,
    fromCache: fromCache,
  );
}

/// The body of a `todaySnapshotProvider.overrideWith` that answers with [view].
///
/// The override itself is written at each call site rather than returned from
/// here, because `Override` is not exported by `flutter_riverpod` and importing
/// it out of the runtime package to save three lines would be reaching past a
/// deliberate boundary.
Future<TodayView> Function(Ref ref) todayIs(TodayView view) =>
    (ref) async => view;

/// The same, for a server that cannot be reached and has nothing cached.
Future<TodayView> Function(Ref ref) todayUnreachable() =>
    (ref) async => throw const SocketException('offline, for the test');
