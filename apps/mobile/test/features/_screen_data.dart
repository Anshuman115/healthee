/// Builds a [ScreenData] for a section-list test, without standing a screen up.
///
/// The section lists are plain functions of `ScreenData` on purpose — order is a
/// decision, not an element in a tree — so the tests that are about ORDER can
/// call them directly. That is much stronger than scrolling a rendered list and
/// reading it back: it asserts what the screen decided, not what happened to be
/// on screen when the scroll stopped.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/reveal_once.dart';

/// One render's inputs. [day] defaults to a phone that has synced nothing, so a
/// test that cares only about the server half does not have to build a day.
ScreenData screenData({
  DeviceDay? day,
  TodayView? server,
  AsyncValue<TodayView>? serverState,
  DateTime? now,
}) {
  return ScreenData(
    day: day ?? DeviceDay.empty('2026-08-04'),
    server: serverState ??
        (server == null
            ? const AsyncLoading<TodayView>()
            : AsyncData<TodayView>(server)),
    reveals: RevealRegistry(),
    onRetryServer: () {},
    // Pinned by default, and it is load-bearing rather than tidy: Today decides
    // whether last night's readings are stale by comparing the payload's own
    // `end_iso` to this instant. Left to the wall clock, the contract snapshot
    // ages past 24 h and the stale-sleep banner appears in every test that
    // never asked about it.
    now: now ?? DateTime(2026, 7, 31, 9, 30),
  );
}
