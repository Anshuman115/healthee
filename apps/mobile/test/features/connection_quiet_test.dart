/// Nothing may be quiet while anything is wrong — the other half of
/// `today_connection_surface_test.dart`.
///
/// That file asks whether every loud state reaches a surface. This one asks the
/// inverse and it is the harder question, because its failure mode is silence:
/// a classifier that answers *quiet* for a broken phone produces a screen that
/// looks completely fine, and no assertion about what is drawn can catch it.
///
/// So the assertions here are about the classification itself, driven from the
/// same facts the screen is:
///
///   * flipping ONE fact off healthy must flip `quiet` — and must move the ring,
///     which reads `quiet` rather than deciding for itself;
///   * every loud `HealthLine` must appear in `alerts`, iterated rather than
///     enumerated, so a new line cannot be added without a surface;
///   * every loud line must have a headline, which `HealthLine.alarm` enforces
///     at compile time and this checks has stayed enforced;
///   * the two LINK faults must be alerts even though no health line describes
///     them — the half that had nowhere to go when the strip was deleted.
///
/// `test/mutations.sh` breaks each of these on purpose.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/prune_report.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/health_lines.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';
import 'package:healthee/shared/connection/sync_ring.dart';

import '_connection_fixtures.dart';
import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('the quiet state', () {
    test('a healthy phone classifies as quiet', () {
      expect(healthyConnection().quiet, isTrue);
      expect(healthyConnection().alerts, isEmpty);
    });

    for (final probe in unhealthyCases) {
      test('${probe.name} is not quiet', () {
        expect(
          probe.health.quiet,
          isFalse,
          reason: '${probe.name} must be loud, never a resting ring',
        );
      });
    }

    testWidgets('the card renders NOTHING, not an empty one', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DataHealthSection(
              connection: healthyConnection(),
              push: const PushStamp.never(),
              signedIn: true,
              lastStrapSync: now.subtract(const Duration(minutes: 4)),
              now: now,
            ),
          ),
        ),
      );
      await tester.pump();

      // Zero height, not "a thin card saying Connected". The room is the feature.
      expect(tester.getSize(find.byType(DataHealthSection)), Size.zero);
    });

    testWidgets('the ring is the whole of it, in the header row', (tester) async {
      await tester.pumpWidget(todayHost(store, connection: Connected(since: now)));
      await tester.pump();

      expect(find.byType(SyncRing), findsOneWidget);
    });
  });

  group('MUTATION: a fault cannot render as the quiet one', () {
    // The failure mode is not a wrong sentence — it is silence. These drive the
    // classifier from the same facts the screen does and assert that flipping
    // ONE input from healthy to broken flips `quiet`. If a future refactor makes
    // a widget decide "quiet" for itself, or drops a branch, these go red.
    test('flipping any single fact off healthy makes it loud', () {
      final mutations = <String, ConnectionHealth>{
        'the link failed': connectionHealth(
          link: const ConnectionFailed(kBluetoothOff),
          now: now,
          signedIn: true,
          lastStrapSync: now,
        ),
        'signed out': connectionHealth(
          link: Disconnected(lastCompleteSync: now),
          now: now,
          signedIn: false,
          lastStrapSync: now,
        ),
        'push faulted': connectionHealth(
          link: Disconnected(lastCompleteSync: now),
          now: now,
          signedIn: true,
          lastStrapSync: now,
          push: PushStamp(
            lastAttempt: now,
            outcomeId: 'transport',
            failureReason: 'nope',
            pendingRows: 1,
          ),
        ),
        'strap unread past the horizon': connectionHealth(
          link: Disconnected(lastCompleteSync: now),
          now: now,
          signedIn: true,
          lastStrapSync: now.subtract(kStrapHorizonWarning * 3),
        ),
      };
      for (final entry in mutations.entries) {
        expect(
          entry.value.quiet,
          isFalse,
          reason: '${entry.key}: a resting ring here would hide a real fault',
        );
        expect(
          ringStateOf(entry.value),
          SyncRingState.needsAttention,
          reason: '${entry.key}: and the ring follows `quiet` rather than guess',
        );
      }
    });

    test('EVERY loud health line reaches the surface as an alert', () {
      // The classifier iterates `dataHealthLines` rather than naming the faults
      // it knows about, so this is the guard that the two cannot drift: a loud
      // line added to `health_lines.dart` with no branch here would be invisible.
      final lines = dataHealthLines(
        now: now,
        signedIn: false,
        lastStrapSync: now.subtract(kStrapHorizonWarning * 2),
        push: PushStamp(
          lastAttempt: now,
          outcomeId: 'transport',
          failureReason: 'nope',
          pendingRows: 12,
          loss: const UnsentLoss(rows: 3, throughDay: '2025-01-01'),
        ),
      );
      final loud = lines.where((line) => line.loud).map((line) => line.id);
      expect(loud, isNotEmpty, reason: 'the fixture has to actually be broken');

      final health = connectionHealth(
        link: Disconnected(lastCompleteSync: now),
        now: now,
        signedIn: false,
        lastStrapSync: now.subtract(kStrapHorizonWarning * 2),
        push: PushStamp(
          lastAttempt: now,
          outcomeId: 'transport',
          failureReason: 'nope',
          pendingRows: 12,
          loss: const UnsentLoss(rows: 3, throughDay: '2025-01-01'),
        ),
      );
      expect(health.alerts.map((alert) => alert.id), containsAll(loud));
    });

    test('a loud line always has a headline a surface can draw', () {
      // `HealthLine.alarm` requires one, so this cannot fail by construction —
      // which is the point. It fails the day somebody adds a `loud` flag back to
      // the plain constructor, which is exactly when it would stop being true.
      final lines = dataHealthLines(
        now: now,
        signedIn: false,
        lastStrapSync: now.subtract(kStrapHorizonWarning * 2),
        push: PushStamp(
          lastAttempt: now,
          outcomeId: 'transport',
          failureReason: 'nope',
          pendingRows: 12,
        ),
      );
      for (final line in lines.where((line) => line.loud)) {
        expect(line.headline, isNotNull, reason: '${line.id} would be silent');
        expect(line.headline, isNotEmpty);
        expect(line.id, isNotEmpty);
      }
    });

    test('a LINK fault is an alert even though it has no health line', () {
      // The half that had no surface before the card took it. `dataHealthLines`
      // knows nothing about a radio, so nothing downstream of it can carry these
      // two, and a `dataAlerts`-only card would drop them in silence.
      for (final probe in <ConnectionHealth>[
        connectionHealth(
          link: const ConnectionFailed(kBluetoothOff),
          now: now,
          signedIn: true,
          lastStrapSync: now,
        ),
        connectionHealth(link: const Disconnected(), now: now, signedIn: true),
      ]) {
        expect(probe.linkAlerts, hasLength(1));
        expect(probe.linkAlerts.single.detail, isNotNull);
        expect(probe.alerts, contains(probe.linkAlerts.single));
      }
    });
  });

  group('the link still speaks in its own words', () {
    for (final (name, state, expected) in <(String, StrapConnection, String)>[
      ('scanning', const Scanning(), 'Looking for your strap'),
      ('connecting', const Connecting(), 'Connecting'),
      ('authenticating', const Authenticating(), 'Authenticating'),
      ('syncing', const Syncing(), 'Syncing'),
    ]) {
      test('$name keeps its own sentence, now as the ring label', () {
        final health = connectionHealth(link: state, now: now, signedIn: true);
        expect(ringStateOf(health), SyncRingState.syncing);
        expect(ringLabel(health), expected);
      });
    }

    test('an idle link says how fresh the data is, not what the socket is', () {
      expect(ringLabel(healthyConnection()), 'Synced 4 min ago');
    });

    test('NEVER-SYNCED NO LONGER NAMES A DELETED BUTTON', () {
      // `Sync now` lived on the connection strip. Telling somebody to tap a
      // control that is not on the screen is worse than telling them nothing.
      final report = connectionHealth(
        link: const Disconnected(),
        now: now,
        signedIn: true,
      ).report;
      expect(report.headline, 'Never synced — pull down to sync');
    });

    testWidgets('AN IDLE LINK IS NEVER REPORTED AS A FAULT', (tester) async {
      // The app let the link go on purpose. It is not reported at all.
      await tester.pumpWidget(headerWith(healthyConnection()));
      await tester.pump();

      expect(ringStateOf(healthyConnection()), SyncRingState.idle);
      expect(find.text('Not connected'), findsNothing);
    });
  });
}
