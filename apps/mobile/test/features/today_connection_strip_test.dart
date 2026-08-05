/// The connection surface — quiet when there is nothing to say, and loud for
/// **every** state where there is.
///
/// The permanent "Connected · Sync now" strip is gone. What replaced it is a 7 px
/// dot in the header row, and the whole design rests on one claim:
///
/// > A quiet healthy state is only honest if every unhealthy state is genuinely
/// > loud.
///
/// So the centre of this file is not "does the dot render". It is the enumeration
/// below — every state that must open the strip, each pumped, each asserted — and
/// the mutation test under it, which reaches into the classifier's own inputs and
/// checks that a fault cannot come out the quiet side. **A collapsing indicator
/// that swallows a real fault is strictly worse than the sticky strip it
/// replaced**, so that is the assertion the rest of the file exists to support.
///
/// Split from `today_screen_test.dart` when that file passed the 400-line gate,
/// and the split is by responsibility: this suite is about the LINK and the pipe,
/// the other is about what the screen draws from a payload.
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
import 'package:healthee/data/sync/sync_failure.dart';
import 'package:healthee/shared/connection/connection_dot.dart';
import 'package:healthee/shared/connection/connection_strip.dart';

import '_today_host.dart';

const SyncFailure _bluetoothOff = SyncFailure(
  headline: 'Bluetooth is off',
  remedy: 'Turn Bluetooth on and try again.',
  code: 'bluetooth_off',
  source: 'test',
);

/// A phone with nothing wrong: a sync finished four minutes ago, a session is
/// held, the push is clear.
ConnectionHealth _healthy() => connectionHealth(
  link: Disconnected(lastCompleteSync: now.subtract(const Duration(minutes: 4))),
  now: now,
  push: const PushStamp.never(),
  signedIn: true,
  lastStrapSync: now.subtract(const Duration(minutes: 4)),
);

/// Every state that MUST be loud, with the sentence the strip has to carry.
///
/// A list rather than six `testWidgets` bodies, because the point is the
/// enumeration: adding a failure state without adding it here is the mistake
/// this design is exposed to, and a table makes the omission visible in review.
final List<(String, ConnectionHealth, String)> _unhealthy =
    <(String, ConnectionHealth, String)>[
      (
        'the strap could not be reached',
        connectionHealth(
          link: ConnectionFailed(
            _bluetoothOff,
            lastCompleteSync: now.subtract(const Duration(hours: 9)),
          ),
          now: now,
          signedIn: true,
          lastStrapSync: now.subtract(const Duration(hours: 9)),
        ),
        'Bluetooth is off',
      ),
      (
        'nothing has ever been read from the strap',
        connectionHealth(link: const Disconnected(), now: now, signedIn: true),
        'Nothing has been read from your strap yet',
      ),
      (
        'this phone is not signed in',
        connectionHealth(
          link: Disconnected(lastCompleteSync: now),
          now: now,
          signedIn: false,
          lastStrapSync: now,
        ),
        'Not signed in to a server',
      ),
      (
        'the push is faulted',
        connectionHealth(
          link: Disconnected(lastCompleteSync: now),
          now: now,
          signedIn: true,
          lastStrapSync: now,
          push: PushStamp(
            lastAttempt: now,
            outcomeId: 'transport',
            failureReason: 'the server closed the connection',
            pendingRows: 900,
          ),
        ),
        'Your data is not reaching the server',
      ),
      (
        'the strap has gone unread past its horizon',
        connectionHealth(
          link: Disconnected(
            lastCompleteSync: now.subtract(kStrapHorizonWarning * 2),
          ),
          now: now,
          signedIn: true,
          lastStrapSync: now.subtract(kStrapHorizonWarning * 2),
        ),
        'Your strap has not been read in days',
      ),
      (
        'measurements were destroyed before they were sent',
        connectionHealth(
          link: Disconnected(lastCompleteSync: now),
          now: now,
          signedIn: true,
          lastStrapSync: now,
          push: PushStamp(
            lastAttempt: now,
            pendingRows: 0,
            outcomeId: 'pruned',
            loss: const UnsentLoss(rows: 4210, throughDay: '2025-08-04'),
          ),
        ),
        'Measurements were lost before they were sent',
      ),
    ];

Widget _strip(ConnectionHealth health) => MaterialApp(
  // The app's real theme: `context.colors` reads the `HealtheeColors` extension
  // and a bare `MaterialApp` has none, which fails as a null check rather than
  // as anything about the strip.
  theme: AppTheme.light,
  home: Scaffold(
    body: ConnectionStrip(health: health, onRetry: () {}, onStop: () {}),
  ),
);

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('the quiet state', () {
    test('a healthy phone classifies as quiet', () {
      expect(_healthy().quiet, isTrue);
      expect(_healthy().alerts, isEmpty);
    });

    testWidgets('the strip renders NOTHING, not an empty bar', (tester) async {
      await tester.pumpWidget(_strip(_healthy()));
      await tester.pump();

      // Zero height, not "a thin bar saying Connected". The room is the feature.
      expect(tester.getSize(find.byType(ConnectionStrip)), Size.zero);
    });

    testWidgets('the dot is in the header row, beside the date', (tester) async {
      await tester.pumpWidget(todayHost(store, connection: Connected(since: now)));
      await tester.pump();

      expect(find.byType(ConnectionDot), findsOneWidget);
      expect(
        find.text('Sync now'),
        findsNothing,
        reason: 'pull-to-refresh is the manual path; the button is not chrome',
      );
    });
  });

  group('EVERY UNHEALTHY STATE IS LOUD', () {
    for (final (name, health, headline) in _unhealthy) {
      test('$name is not quiet', () {
        expect(
          health.quiet,
          isFalse,
          reason: '$name must open the strip, never collapse to a dot',
        );
      });

      testWidgets('$name says so on the strip', (tester) async {
        await tester.pumpWidget(_strip(health));
        await tester.pump();

        expect(find.byType(ConnectionDot), findsOneWidget);
        expect(find.textContaining(headline), findsOneWidget);
      });
    }

    testWidgets('a link failure carries its remedy in full', (tester) async {
      // Nothing else on the screen says how to fix a radio, so the strip owns
      // this one rather than deferring to the data-health card.
      await tester.pumpWidget(_strip(_unhealthy.first.$2));
      await tester.pump();

      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(find.text('Last full sync 9 h ago.'), findsOneWidget);
      expect(find.text('Turn Bluetooth on and try again.'), findsOneWidget);
    });
  });

  group('MUTATION: a fault cannot render as the quiet one', () {
    // The failure mode is not a wrong sentence — it is silence. These drive the
    // classifier from the same facts the screen does and assert that flipping
    // ONE input from healthy to broken flips `quiet`. If a future refactor makes
    // the strip decide "quiet" for itself, or drops a branch, these go red.
    test('flipping any single fact off healthy makes it loud', () {
      final mutations = <String, ConnectionHealth>{
        'the link failed': connectionHealth(
          link: const ConnectionFailed(_bluetoothOff),
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
          reason: '${entry.key}: a quiet dot here would hide a real fault',
        );
      }
    });

    test('EVERY loud health line reaches the strip as an alert', () {
      // The strip iterates `dataHealthLines` rather than naming the faults it
      // knows about, so this is the guard that the two cannot drift: a loud line
      // added to `health_lines.dart` with no branch here would be invisible.
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

    test('a loud line always has a headline the strip can draw', () {
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
  });

  group('a sync in flight stays visible', () {
    testWidgets('a busy link opens the strip even with nothing wrong', (
      tester,
    ) async {
      final health = connectionHealth(
        link: const Authenticating(),
        now: now,
        signedIn: true,
        lastStrapSync: now,
      );
      expect(health.alerts, isEmpty, reason: 'busy is not a fault');
      expect(health.quiet, isFalse, reason: 'and it is not quiet either');

      await tester.pumpWidget(_strip(health));
      await tester.pump();
      expect(find.text('Authenticating'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(
        find.text('Sync now'),
        findsNothing,
        reason: 'the strap accepts one connection at a time',
      );
    });

    testWidgets('a stopped-but-broken link offers the sync, not Stop', (
      tester,
    ) async {
      await tester.pumpWidget(_strip(_unhealthy.first.$2));
      await tester.pump();

      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
    });
  });

  group('the link still speaks in its own words', () {
    for (final (name, state, expected) in <(String, StrapConnection, String)>[
      ('never synced', const Disconnected(), 'Never synced — tap Sync now'),
      ('scanning', const Scanning(), 'Looking for your strap'),
      ('connecting', const Connecting(), 'Connecting'),
      ('authenticating', const Authenticating(), 'Authenticating'),
      ('syncing', const Syncing(), 'Syncing'),
    ]) {
      testWidgets('$name renders its own sentence', (tester) async {
        await tester.pumpWidget(
          _strip(connectionHealth(link: state, now: now, signedIn: true)),
        );
        await tester.pump();

        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('AN IDLE LINK IS NEVER REPORTED AS A FAULT', (tester) async {
      // The app let the link go on purpose. It is now not reported at all.
      await tester.pumpWidget(_strip(_healthy()));
      await tester.pump();

      expect(find.text('Not connected'), findsNothing);
      expect(find.textContaining('Synced'), findsNothing);
    });
  });
}
