/// The push end to end: a real store, the real payload, a faked socket.
///
/// Three claims, and they are the whole reason the marker lives on the row:
///
///   * **a failed push loses nothing.** The transport is made to fail; every row
///     is still pending afterwards and the next run sends exactly them.
///   * **a push is idempotent.** Running it twice against a store nothing has
///     touched sends the rows once, because "pending" is a fact on disk rather
///     than a cursor somebody remembered.
///   * **a backfilled row is not skipped.** The one-shot stress and nap passes
///     write rows OLDER than everything already sent. A high-water cursor would
///     have missed every one, permanently.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/push/push_outcome.dart';
import 'package:healthee/data/push/push_service.dart';
import 'package:healthee/data/store/local_store.dart';

import '../store/strap_store_test.dart' show nightOn, resultWith;
import '_push_fakes.dart';

final DateTime _now = DateTime(2026, 8, 4, 9, 30);

/// A service over [store] and [transport].
PushService serviceFor(
  LocalStore store,
  FakeIngestTransport transport, {
  Credentials? credentials,
}) => PushService(
  store: store,
  client: clientOver(transport),
  credentials: credentials ?? signedIn(),
);

/// One ordinary day in the store: a counter, some samples, a night.
Future<void> seedOneDay(LocalStore store) => store.strapWriter.saveSync(
  resultWith(
    totals: DeviceDailyTotals(
      steps: 9264,
      distanceM: 6710,
      calories: 412,
      readAt: DateTime(2026, 8, 4, 9, 12),
    ),
    samples: [
      StrapSample(DateTime(2026, 8, 4, 7), 'hr', 61),
      StrapSample(DateTime(2026, 8, 4, 8), 'hrv', 51),
    ],
    sleep: [nightOn(DateTime(2026, 8, 3, 23, 40))],
  ),
);

void main() {
  late LocalStore store;
  late FakeIngestTransport transport;

  setUp(() {
    store = LocalStore.memory();
    transport = FakeIngestTransport();
  });
  tearDown(() async => store.close());

  group('a good push', () {
    test('sends everything pending and marks it, once', () async {
      await seedOneDay(store);

      final outcome = await serviceFor(store, transport).run(now: _now);

      expect(outcome, isA<PushSent>());
      expect((outcome as PushSent).rows, 4, reason: '2 samples + 1 night + 1 counter');
      expect(transport.calls, 1);
      expect(await store.pushReader.pendingCount(), 0);
    });

    test('A SECOND RUN SENDS NOTHING — the push is idempotent', () async {
      await seedOneDay(store);
      final service = serviceFor(store, transport);

      await service.run(now: _now);
      final second = await service.run(now: _now);

      expect(second, isA<PushSent>());
      expect((second as PushSent).rows, 0);
      expect(
        transport.calls,
        1,
        reason: 'nothing was pending, so nothing was sent — not sent twice',
      );
    });

    test('the receipt is read, and counts the daily total', () async {
      await seedOneDay(store);

      await serviceFor(store, transport).run(now: _now);

      final body = transport.lastBody;
      expect(body['daily_totals']! as List, hasLength(1));
    });
  });

  group('a failed push', () {
    test('A FAILED PUSH LOSES NOTHING — every row is still pending', () async {
      await seedOneDay(store);
      final before = await store.pushReader.pendingCount();
      transport.failWith = 503;

      final outcome = await serviceFor(store, transport).run(now: _now);

      expect(outcome, isA<PushFailed>());
      expect(
        await store.pushReader.pendingCount(),
        before,
        reason: 'rows are marked only after a 2xx; marking optimistically is '
            'permanent data loss with no error anywhere',
      );
    });

    test('the next run sends exactly what did not land', () async {
      await seedOneDay(store);
      // Fail once, then let it through — the resume case.
      transport.failFirst = 1;
      final service = serviceFor(store, transport);

      final first = await service.run(now: _now);
      final second = await service.run(now: _now);

      expect(first, isA<PushFailed>());
      expect(second, isA<PushSent>());
      expect((second as PushSent).rows, 4);
      expect(await store.pushReader.pendingCount(), 0);
    });

    test('it names what went wrong, and keeps it where health can read it', () async {
      await seedOneDay(store);
      transport.failWith = 401;

      await serviceFor(store, transport).run(now: _now);
      final stamp = await store.pushReader.lastAttempt();

      expect(stamp.outcomeId, 'failed');
      expect(stamp.failureReason, contains('did not accept this phone'));
      expect(stamp.lastCompletePush, isNull, reason: 'nothing landed');
      expect(stamp.pendingRows, greaterThan(0));
      expect(stamp.needsAttention, isTrue);
    });

    test('a good push CLEARS the previous failure sentence', () async {
      await seedOneDay(store);
      transport.failWith = 503;
      final service = serviceFor(store, transport);
      await service.run(now: _now);

      transport.failWith = null;
      await service.run(now: _now);
      final stamp = await store.pushReader.lastAttempt();

      expect(
        stamp.failureReason,
        isNull,
        reason: 'a stale failure under a healthy push is a lie with a timestamp',
      );
      expect(stamp.lastCompletePush, _now);
      expect(stamp.needsAttention, isFalse);
    });
  });

  group('rows that arrive out of order', () {
    test('A BACKFILLED OLD ROW IS STILL SENT', () async {
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 8), 'hr', 61)]),
      );
      final service = serviceFor(store, transport);
      await service.run(now: _now);

      // The one-shot stress pass writes a fortnight back, AFTER newer rows have
      // already gone out. A high-water cursor would skip this forever.
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 7, 22, 3), 'stress', 34)]),
      );
      await service.run(now: _now);

      final sent = transport.bodies
          .expand((body) => (body['samples']! as List).cast<Map<String, Object?>>())
          .map((sample) => sample['metric'])
          .toList();
      expect(sent, containsAll(<String>['hr', 'stress']));
    });

    test('a re-pulled night is sent again; a re-pulled sample is not', () async {
      await seedOneDay(store);
      final service = serviceFor(store, transport);
      await service.run(now: _now);

      // The fetch plan re-reads two days of sleep and overlaps samples. Only the
      // night can have changed under its key.
      await seedOneDay(store);
      await service.run(now: _now);

      final second = transport.bodies.last;
      expect(second['sleep']! as List, hasLength(1));
      expect(
        second['samples']! as List,
        isEmpty,
        reason: 're-sending 60 days of unchanged samples every sync buys nothing',
      );
    });
  });

  group('a phone that is not signed in', () {
    test('does not push, does not lose anything, and is not a fault', () async {
      await seedOneDay(store);

      final outcome = await serviceFor(
        store,
        transport,
        credentials: signedOut(),
      ).run(now: _now);

      expect(outcome, isA<PushSkipped>());
      expect(transport.calls, 0);
      expect(
        await store.pushReader.pendingCount(),
        4,
        reason: 'signing in later must send the whole backlog, not start from then',
      );
      final stamp = await store.pushReader.lastAttempt();
      expect(stamp.outcomeId, 'skipped');
      expect(stamp.failureReason, isNull, reason: 'not signed in is not broken');
    });
  });

  test('the strap MAC and AUTHKEY never reach our API', () async {
    // They are per-owner secrets for talking to the STRAP. A request to our
    // server has no business carrying either, and the payload builder has no
    // path to them — this asserts that rather than assuming it.
    await seedOneDay(store);

    await serviceFor(store, transport).run(now: _now);

    final wire = transport.rawBodies.join('\n');
    expect(wire, isNot(contains('authKey')));
    expect(wire, isNot(contains('auth_key')));
    expect(wire, isNot(contains('mac')));
  });
}
