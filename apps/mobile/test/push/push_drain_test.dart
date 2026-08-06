/// The outer drain: it clears a backlog, and it stops when it must.
///
/// The inner page loop is bounded by a fixed count because "until nothing is
/// pending" trusts a marker write it does not verify. The drain is allowed to
/// repeat that loop only because it DOES verify it — `rowsSent > 0` and a
/// pending count that strictly fell. Both exits are exercised here, and the
/// stall exit is exercised with a store whose marker genuinely does nothing,
/// which is the bug the original bound was written against.
///
/// The bounds are cut down through the constructor rather than by seeding
/// 80,000 rows. That is not a shortcut around the real numbers: it is the only
/// way this suite runs the loop exits at all, and a loop guard nobody has run is
/// a loop guard nobody has written.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/push/push_batch.dart';
import 'package:healthee/data/push/push_outcome.dart';
import 'package:healthee/data/push/push_service.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/push_reader.dart';

import '../store/strap_store_test.dart' show resultWith;
import '_push_fakes.dart';

final DateTime _now = DateTime(2026, 8, 4, 9, 30);

/// A store holding [count] samples, one per minute, all pending.
Future<void> seedSamples(LocalStore store, int count) => store.strapWriter
    .saveSync(
      resultWith(
        samples: [
          for (var i = 0; i < count; i++)
            StrapSample(DateTime(2026, 8, 4).add(Duration(minutes: i)), 'hr', 60),
        ],
      ),
    );

/// A reader that reads honestly, sends honestly, and forgets every mark.
///
/// This IS the bug the inner loop's fixed bound was written against: the page is
/// read, the server accepts it, and the write that would say so is dropped — so
/// the same page comes back forever and `rowsSent` climbs the whole time. It is
/// simulated by dropping one method of the real accessor rather than by faking
/// the reader, because a fake would agree with whatever the drain believes.
class ForgetfulPushReader extends PushReader {
  /// [db] is the real in-memory store.
  ForgetfulPushReader(super.db);

  @override
  Future<void> markPushed(PushBatch batch, DateTime at) async {}
}

/// A real store whose push marker does nothing.
class ForgetfulStore extends LocalStore {
  /// A fresh in-memory database, with a forgetful marker over it.
  ForgetfulStore() : super.memory();

  late final ForgetfulPushReader _reader = ForgetfulPushReader(this);

  @override
  PushReader get pushReader => _reader;
}

void main() {
  late LocalStore store;
  late FakeIngestTransport transport;

  setUp(() {
    store = LocalStore.memory();
    transport = FakeIngestTransport();
  });
  tearDown(() async => store.close());

  /// A service whose page loop caps at [maxPages] pages of [pageLimit] samples.
  PushService drainerOver(
    LocalStore over, {
    int pageLimit = 2,
    int maxPages = 2,
    int maxDrainRounds = 12,
  }) => PushService(
    store: over,
    client: clientOver(transport),
    credentials: signedIn(),
    pageLimit: pageLimit,
    maxPages: maxPages,
    maxDrainRounds: maxDrainRounds,
  );

  group('one run, on its own', () {
    test('A PAGE CAP IS NOT A FAULT — it is PushPaused', () async {
      await seedSamples(store, 10);

      final outcome = await drainerOver(store).run(now: _now);

      expect(outcome, isA<PushPaused>());
      expect(outcome.isFault, isFalse, reason: 'the design working, not a fault');
      expect(outcome.rowsSent, 4, reason: '2 pages of 2');
    });

    test('and it writes NO failure reason for the card to shout about', () async {
      await seedSamples(store, 10);

      await drainerOver(store).run(now: _now);
      final stamp = await store.pushReader.lastAttempt();

      expect(stamp.outcomeId, 'paused');
      expect(stamp.failureReason, isNull);
      expect(stamp.isFaulted, isFalse);
      expect(stamp.isDraining, isTrue);
    });

    test('a TRANSPORT DEATH mid-backlog is PushInterrupted, and IS a fault', () async {
      await seedSamples(store, 10);
      // Let the first page through, then kill the socket.
      transport.failAfter = 1;

      final outcome = await drainerOver(store).run(now: _now);

      expect(outcome, isA<PushInterrupted>());
      expect(outcome.isFault, isTrue);
      expect(outcome.rowsSent, 2, reason: 'one page landed before it died');
    });
  });

  group('the drain', () {
    test('CLEARS A BACKLOG THE PAGE CAP CANNOT', () async {
      await seedSamples(store, 10);

      final outcome = await drainerOver(store).drain(now: _now);

      expect(outcome, isA<PushSent>());
      expect(outcome.rowsSent, 10, reason: 'the whole backlog, across rounds');
      expect(await store.pushReader.pendingCount(), 0);
    });

    test('and the stamp counts the WHOLE drain, not its last round', () async {
      await seedSamples(store, 10);

      await drainerOver(store).drain(now: _now);
      final stamp = await store.pushReader.lastAttempt();

      expect(stamp.outcomeId, 'sent');
      expect(stamp.lastCompletePush, _now);
      expect(stamp.pendingRows, 0);
      expect(stamp.needsAttention, isFalse);
    });

    test('a round that sends nothing ENDS IT — there is nothing left', () async {
      // The ordinary exit: one round clears everything, the next would send
      // zero, and the drain never asks for it because the round said `sent`.
      await seedSamples(store, 2);

      await drainerOver(store).drain(now: _now);

      expect(transport.calls, 1, reason: 'one page, one request, then done');
    });

    test('IT STOPS ON A FAILURE and does not retry forever', () async {
      await seedSamples(store, 10);
      transport.failWith = 503;

      final outcome = await drainerOver(store).drain(now: _now);

      expect(outcome, isA<PushFailed>());
      expect(
        transport.calls,
        1,
        reason: 'a dead transport is not slow progress; retrying it in a tight '
            'loop is how a phone burns a battery on the same bad news',
      );
    });

    test('a failure AFTER progress is reported as interrupted, with the total', () async {
      await seedSamples(store, 10);
      // Round one caps out (2 pages), round two dies on its first request.
      transport.failAfter = 2;

      final outcome = await drainerOver(store).drain(now: _now);

      expect(outcome, isA<PushInterrupted>());
      expect(outcome.isFault, isTrue);
      expect(outcome.rowsSent, 4, reason: 'what actually landed, across rounds');
    });

    test('it stops when there is no token, and that is not a fault', () async {
      await seedSamples(store, 10);

      final outcome = await PushService(
        store: store,
        client: clientOver(transport),
        credentials: signedOut(),
      ).drain(now: _now);

      expect(outcome, isA<PushSkipped>());
      expect(outcome.isFault, isFalse);
      expect(transport.calls, 0);
    });

    test('THE ROUND CAP HOLDS when the backlog outruns it', () async {
      // Progress is real every round, so only the backstop can stop this.
      await seedSamples(store, 40);

      final outcome = await drainerOver(store, maxDrainRounds: 3).drain(now: _now);

      expect(outcome, isA<PushPaused>());
      expect(outcome.isFault, isFalse, reason: 'still not a fault: it moved data');
      expect(outcome.rowsSent, 12, reason: '3 rounds × 2 pages × 2 samples');
      expect(await store.pushReader.pendingCount(), 28);
    });
  });

  group('a keystore that will not answer', () {
    test('IS A REPORTED FAULT, not an exception nobody catches', () async {
      // `run` documents that it never throws, and that stopped being a nicety
      // when the push became unattended: a throw inside a foreground transition
      // has no caller and no screen to land on.
      await seedSamples(store, 2);

      final outcome = await PushService(
        store: store,
        client: clientOver(transport),
        credentials: const Credentials(RefusingSecretStore()),
      ).drain(now: _now);

      expect(outcome, isA<PushFailed>());
      expect(outcome.isFault, isTrue);
      expect((outcome as PushFailed).reason, contains('secure storage'));
      final stamp = await store.pushReader.lastAttempt();
      expect(stamp.failureReason, isNotNull, reason: 'it reached the surface');
    });
  });

  group('the marker bug the inner bound was written against', () {
    late ForgetfulStore forgetful;

    setUp(() => forgetful = ForgetfulStore());
    tearDown(() async => forgetful.close());

    test('A QUEUE THAT STOPS SHRINKING STOPS THE DRAIN', () async {
      await seedSamples(forgetful, 10);

      final outcome = await drainerOver(forgetful).drain(now: _now);

      expect(
        transport.calls,
        2,
        reason: 'ONE round of two pages, then the pending count said the same '
            'number it said before and the drain stopped. `rowsSent > 0` was '
            'true the whole time — it reported 4 rows sent against a queue that '
            'never moved — so that check alone would have run to the round cap: '
            '12 rounds, 24 requests, resending the same two samples',
      );
      expect(outcome, isA<PushInterrupted>());
      expect(
        outcome.rowsSent,
        4,
        reason: 'said plainly: the server did acknowledge these, twice',
      );
    });

    test('and it is reported as a FAULT, because nothing will clear it', () async {
      await seedSamples(forgetful, 10);

      final outcome = await drainerOver(forgetful).drain(now: _now);
      final stamp = await forgetful.pushReader.lastAttempt();

      expect((outcome as PushInterrupted).reason, contains('not reducing'));
      expect(stamp.isFaulted, isTrue);
      expect(
        stamp.isDraining,
        isFalse,
        reason: '"still going out" would be a promise nothing can keep — the '
            'next sync takes the same page and stalls in the same place',
      );
    });
  });
}
