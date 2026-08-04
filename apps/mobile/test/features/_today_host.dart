/// The Today host every widget suite in this directory pumps.
///
/// Extracted on its second use (Standards §1). Two suites now render this
/// screen — one about what it draws, one about the connection strip in its
/// chrome — and a second copy of these overrides is a second chance to forget
/// one of them, which shows up as "pumpAndSettle timed out" rather than as
/// anything about the test.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/today/today_screen.dart';

import '../_today_stubs.dart';
import '../store/strap_store_test.dart' show nightOn, resultWith;

const String todayDate = '2026-08-04';
final DateTime now = DateTime(2026, 8, 4, 9, 30);

/// The screen over [store], with the day, the clock, the link and the payload
/// all pinned.
///
/// The connection is ALWAYS overridden, even when a test does not care about
/// it. The real controller opens a strap session as soon as anything watches it
/// — which is the point of the feature and exactly wrong inside a widget test,
/// where it would reach for a radio that does not exist. The lifecycle
/// behaviour has its own suite (`test/sync/foreground_lifecycle_test.dart`)
/// against a scripted device.
Widget todayHost(
  LocalStore store, {
  StrapConnection? connection,
  TodayView? server,
  bool serverUnreachable = false,
}) {
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      todayProvider.overrideWithValue(todayDate),
      syncControllerProvider.overrideWith(
        () => _FixedConnection(connection ?? const Disconnected()),
      ),
      todaySnapshotProvider.overrideWith(
        serverUnreachable ? todayUnreachable() : todayIs(server ?? todayView()),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: TodayScreen(now: now)),
  );
}

/// A controller pinned to one state, so each case can be rendered on its own.
class _FixedConnection extends SyncController {
  _FixedConnection(this._state);

  final StrapConnection _state;

  @override
  StrapConnection build() => _state;
}

/// Seeds one ordinary day of strap measurements.
Future<void> seedDevice(LocalStore store) async {
  await store.strapWriter.saveSync(
    resultWith(
      totals: DeviceDailyTotals(
        steps: 9264,
        distanceM: 6710,
        calories: 412,
        readAt: DateTime(2026, 8, 4, 9, 12),
      ),
      samples: [
        StrapSample(DateTime(2026, 8, 4, 7), 'hr', 61),
        StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68),
        StrapSample(DateTime(2026, 8, 4, 8), 'hrv', 47),
      ],
      sleep: [nightOn(DateTime(2026, 8, 3, 23, 40))],
      battery: 71,
    ),
  );
  await store.strapWriter.stampAttempt(
    at: DateTime(2026, 8, 4, 9, 12),
    outcomeId: 'complete',
    complete: true,
  );
}

/// Scrolls until [finder] is on screen. The list is a `ListView.builder`, so
/// most of Today is not built until it is needed — which is the point of it.
Future<void> reveal(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 400);

