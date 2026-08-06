/// The drain, over rows the horizon deliberately kept past 60 days.
///
/// `horizon_prune.dart` now retains an unsent measurement rather than deleting
/// it, which puts rows in front of the drain that used to be destroyed before it
/// ever saw them. Two things had to stay true and neither is obvious:
///
///   * **the retained row is still reachable.** Retention that hid a row from
///     `pending()` would trade a silent deletion for a silent orphan — the row
///     would sit on disk forever, counted in the backlog, and never sent.
///   * **the drain still terminates.** Its exit is "the pending count strictly
///     fell", and the retained rows are ordinary pending rows, so the count that
///     the exit reads is the same count it always read — larger, and still
///     falling. This file runs it with the page bounds cut down so the
///     multi-round path is actually exercised rather than argued.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/models/workout.dart';
import 'package:healthee/data/push/push_outcome.dart';
import 'package:healthee/data/push/push_service.dart';
import 'package:healthee/data/store/local_store.dart';

import '../store/strap_store_test.dart' show nightOn, resultWith;
import '_push_fakes.dart';
import 'push_drain_test.dart' show ForgetfulStore;

const String _today = '2026-08-04';
final DateTime _todayAt = DateTime(2026, 8, 4);
final DateTime _now = DateTime(2026, 8, 4, 9, 30);

void main() {
  late LocalStore store;
  late FakeIngestTransport transport;

  setUp(() {
    store = LocalStore.memory();
    transport = FakeIngestTransport();
  });
  tearDown(() async => store.close());

  /// One row in each measurement table, [daysAgo] back and unsent.
  Future<void> seedInto(LocalStore into, int daysAgo) {
    final at = _todayAt.subtract(Duration(days: daysAgo));
    return into.strapWriter.saveSync(
      resultWith(
        samples: [StrapSample(at, 'hr', 60)],
        sleep: [nightOn(at)],
        workouts: [
          Workout(
            start: at,
            sportType: 6,
            durationSec: 600,
            calories: 40,
            avgHr: 100,
            maxHr: 120,
            minHr: 80,
          ),
        ],
        totals: DeviceDailyTotals(
          steps: 100,
          distanceM: 80,
          calories: 5,
          readAt: at,
        ),
      ),
    );
  }

  Future<void> seedAt(int daysAgo) => seedInto(store, daysAgo);

  PushService drainerOver(
    LocalStore over, {
    int pageLimit = 1,
    int maxPages = 2,
  }) => PushService(
    store: over,
    client: clientOver(transport),
    credentials: signedIn(),
    pageLimit: pageLimit,
    maxPages: maxPages,
  );

  PushService drainer({int pageLimit = 1, int maxPages = 2}) =>
      drainerOver(store, pageLimit: pageLimit, maxPages: maxPages);

  test('IT TERMINATES, and sends what the horizon kept for it', () async {
    // 200 and 190 days back are past the 60-day horizon and inside the one-year
    // bound; before the fix neither would have existed to send.
    for (final daysAgo in [200, 190, 61]) {
      await seedAt(daysAgo);
    }
    await store.pruneBeyondHorizon(_today, at: _now);
    expect(
      await store.pushReader.pendingCount(),
      12,
      reason: 'three days × four tables, none of them pruned',
    );

    final outcome = await drainer().drain(now: _now);

    expect(outcome, isA<PushSent>());
    expect(outcome.rowsSent, 12);
    expect(await store.pushReader.pendingCount(), 0);
  });

  test('a retained row does NOT make it spin — the stall exit still holds', () async {
    // The termination argument, re-run with retained rows in the queue: a
    // marker that writes nothing leaves the pending count flat, and the drain
    // stops on that rather than on the row count it is being told about. Rows
    // this old are exactly the ones that used to be deleted before the drain
    // could see them, so this exit had never been exercised over them.
    final forgetful = ForgetfulStore();
    addTearDown(forgetful.close);
    for (final daysAgo in [300, 200, 100]) {
      await seedInto(forgetful, daysAgo);
    }
    await forgetful.pruneBeyondHorizon(_today, at: _now);

    final outcome = await drainerOver(forgetful).drain(now: _now);

    expect(outcome, isA<PushInterrupted>());
    expect(
      transport.calls,
      2,
      reason: 'one round of two pages, then the count said the same number '
          'it said before and the drain stopped',
    );
  });

  test('and the NEXT prune takes them, as sent rather than as a loss', () async {
    // Retention is not a leak. The moment the server acknowledges a row, the
    // ordinary 60-day horizon applies to it again.
    await seedAt(200);
    await store.pruneBeyondHorizon(_today, at: _now);
    await drainer(pageLimit: 4000, maxPages: 20).drain(now: _now);

    final report = await store.pruneBeyondHorizon(_today, at: _now);

    expect(report.sentMeasurements, 4);
    expect(report.unsentSamples, 0);
    expect(report.destroyedSomething, isFalse);
    expect(await store.pushReader.pendingCount(), 0);
  });
}
