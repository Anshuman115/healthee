/// The connection strip — the chrome above Today, in every state it has.
///
/// Split from `today_screen_test.dart` when that file passed the 400-line gate.
/// The split is by responsibility rather than by size: this suite is about the
/// LINK to the strap, which is a fact about the radio, while the other is about
/// what the screen draws from a payload. They fail for different reasons and
/// they are read by different people.
///
/// The one claim worth naming: **an idle link is never reported as a fault.**
/// The app lets the session go on purpose when it goes to the background, and a
/// strip that called that "Not connected" would send the owner to check their
/// Bluetooth over nothing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_failure.dart';

import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('the connection strip', () {
    for (final (name, state, expected) in <(String, StrapConnection, String)>[
      ('never synced', const Disconnected(), 'Never synced — tap Sync now'),
      (
        'released after a healthy sync',
        Disconnected(lastCompleteSync: now.subtract(const Duration(minutes: 4))),
        'Synced 4 min ago',
      ),
      ('scanning', const Scanning(), 'Looking for your strap'),
      ('connecting', const Connecting(), 'Connecting'),
      ('authenticating', const Authenticating(), 'Authenticating'),
      ('syncing', const Syncing(), 'Syncing'),
      ('connected', Connected(since: now), 'Connected'),
    ]) {
      testWidgets('$name renders its own sentence', (tester) async {
        await tester.pumpWidget(todayHost(store, connection: state));
        await tester.pump();

        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('AN IDLE LINK IS NEVER REPORTED AS A FAULT', (tester) async {
      await tester.pumpWidget(
        todayHost(
          store,
          connection: Disconnected(
            lastCompleteSync: now.subtract(const Duration(minutes: 4)),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Not connected'),
        findsNothing,
        reason: 'the app let the link go on purpose; nothing is wrong',
      );
    });

    testWidgets('a failure shows the headline, the age AND the remedy', (
      tester,
    ) async {
      const failure = SyncFailure(
        headline: 'Bluetooth is off',
        remedy: 'Turn Bluetooth on and try again.',
        code: 'bluetooth_off',
        source: 'test',
      );
      await tester.pumpWidget(
        todayHost(
          store,
          connection: ConnectionFailed(
            failure,
            lastCompleteSync: now.subtract(const Duration(hours: 9)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(find.text('Last full sync 9 h ago.'), findsOneWidget);
      expect(find.text('Turn Bluetooth on and try again.'), findsOneWidget);
    });

    testWidgets('a busy state offers Stop, never a second Sync now', (
      tester,
    ) async {
      // The strap accepts one connection at a time, so a second "sync now"
      // during a handshake would fail on the radio and report a confusing
      // "couldn't connect" for a strap that is right there, talking to us.
      await tester.pumpWidget(todayHost(store, connection: const Authenticating()));
      await tester.pump();

      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
    });

    testWidgets('an idle state offers Sync now', (tester) async {
      await tester.pumpWidget(todayHost(store, connection: const Disconnected()));
      await tester.pump();

      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
    });
  });
}
