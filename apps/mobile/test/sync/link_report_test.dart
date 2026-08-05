/// The indicator's words, against a pinned clock.
///
/// Two rules are under test and they pull in opposite directions, which is why
/// both need a case here:
///
///   * **never claim a session that is not open.** No state except `Connected`
///     may produce the word, and the sweep at the bottom asserts that over the
///     whole union rather than case by case.
///   * **never alarm about a normal resting state.** After a healthy sync the
///     app releases the link on purpose; "Not connected" describes that in the
///     words of a fault, and the owner's real question — how fresh are these
///     numbers — goes unanswered.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/strap_progress.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/link_report.dart';
import 'package:healthee/data/sync/sync_failure.dart';

final DateTime _now = DateTime(2026, 8, 4, 9, 30);

void main() {
  group('a session is open', () {
    test('says Connected, and marks the link live', () {
      final report = linkReport(Connected(since: _now), now: _now);

      expect(report.headline, 'Connected');
      expect(report.live, isTrue);
    });

    test('a sync in flight is live too — it runs over an open session', () {
      final report = linkReport(
        const Syncing(
          progress: StrapSyncProgress(step: 3, total: 13, label: 'sleep'),
        ),
        now: _now,
      );

      expect(report.headline, 'Syncing — sleep');
      expect(report.live, isTrue);
    });
  });

  group('work in flight names the step it is on', () {
    for (final (state, expected) in <(StrapConnection, String)>[
      (const Scanning(), 'Looking for your strap'),
      (const Connecting(), 'Connecting'),
      (const Authenticating(), 'Authenticating'),
      (const Syncing(), 'Syncing'),
    ]) {
      test(expected, () {
        final report = linkReport(state, now: _now);

        expect(report.headline, expected);
        expect(report.detail, isNull);
      });
    }
  });

  group('no session, and nothing wrong', () {
    test('REPORTS THE FRESHNESS, NOT THE SOCKET', () {
      final report = linkReport(
        Disconnected(lastCompleteSync: _now.subtract(const Duration(minutes: 4))),
        now: _now,
      );

      expect(report.headline, 'Synced 4 min ago');
      expect(report.live, isFalse);
      expect(
        report.headline,
        isNot(contains('Not connected')),
        reason: 'a link released on purpose is not a fault',
      );
    });

    test('an older sync is floored, never rounded flatteringly', () {
      final report = linkReport(
        Disconnected(
          lastCompleteSync: _now.subtract(const Duration(hours: 2, minutes: 55)),
        ),
        now: _now,
      );

      expect(report.headline, 'Synced 2 h ago');
    });

    test('a phone that has never synced says exactly that', () {
      final report = linkReport(const Disconnected(), now: _now);

      // Not "tap Sync now": that button was on the connection strip, and the
      // strip is deleted. Pull-to-refresh is the manual path.
      expect(report.headline, 'Never synced — pull down to sync');
    });
  });

  group('the strap cannot be reached', () {
    ConnectionFailed failed({DateTime? lastSync}) => ConnectionFailed(
      SyncFailure.pairing(const BluetoothOff()),
      lastCompleteSync: lastSync,
    );

    test('shows WHY, and how old the numbers therefore are', () {
      final report = linkReport(
        failed(lastSync: _now.subtract(const Duration(hours: 9))),
        now: _now,
      );

      expect(report.headline, 'Bluetooth is off');
      expect(report.freshness, 'Last full sync 9 h ago.');
      expect(report.detail, contains('Turn Bluetooth on'));
      expect(report.live, isFalse);
    });

    test('a phone with nothing stored says so rather than omitting the line', () {
      final report = linkReport(failed(), now: _now);

      expect(report.freshness, 'Nothing has ever been pulled from the strap.');
    });

    test('the taxonomy keeps its own words — held elsewhere is not out of range', () {
      final report = linkReport(
        ConnectionFailed(SyncFailure.strap(const StrapHeldElsewhere())),
        now: _now,
      );

      expect(report.headline, 'Another app on this phone is holding the strap');
      expect(report.detail, contains('Zepp'));
    });
  });

  test('"CONNECTED" IS UNREACHABLE FROM EVERY OTHER STATE', () {
    final everythingElse = <StrapConnection>[
      const Disconnected(),
      Disconnected(lastCompleteSync: _now),
      const Scanning(),
      const Connecting(),
      const Authenticating(),
      const Syncing(),
      ConnectionFailed(SyncFailure.pairing(const BluetoothOff())),
      ConnectionFailed(
        SyncFailure.strap(const StrapHeldElsewhere()),
        lastCompleteSync: _now,
      ),
    ];

    for (final state in everythingElse) {
      final report = linkReport(state, now: _now);
      expect(
        report.headline,
        isNot('Connected'),
        reason: '${state.runtimeType} has no live session to claim one from',
      );
      expect(
        report.live && state is! Syncing,
        isFalse,
        reason: 'the live mark is evidence of an open session, not decoration',
      );
    }
  });
}
