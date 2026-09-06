/// The strip is gone, and **every** state it used to carry still reaches the
/// owner.
///
/// The permanent "Connected · Sync now" bar is deleted, and so is the 7 px dot
/// that briefly replaced it. What carries the answer now is a ring round the
/// avatar plus the data-health card, and the whole design still rests on one
/// claim:
///
/// > A quiet healthy state is only honest if every unhealthy state is genuinely
/// > loud.
///
/// **Deleting a surface is the moment that claim is easiest to break**, because
/// a fault that used to be drawn simply stops being drawn and nothing fails. So
/// the centre of this file is the enumeration in `_connection_fixtures.dart` —
/// every state that must be loud, each pumped, each asserted **as a sentence on
/// the card** — plus one assertion per case that walks `health.alerts` instead
/// of naming the six it knows about, so a seventh fault with no home fails here
/// rather than shipping silent.
///
/// A ring cannot say *"your token was rotated"*, so the split is deliberate: the
/// ring says **that** something is wrong, the card says **what**, and the ring's
/// spoken label points at the card. `connection_quiet_test.dart` is the other
/// half — that nothing may be quiet while any of this is true.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/health_lines.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/connection/sync_ring.dart';

import '_connection_fixtures.dart';
import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('THE TOP STRIP IS GONE', () {
    testWidgets('the header is the first thing on the screen, even when loud', (
      tester,
    ) async {
      // Geometry, not the absence of a class name: the class is deleted, so a
      // `findsNothing` would pass against a bar re-added under another name.
      // What is asserted is the room — the strip cost about a tenth of the
      // screen, and the header now starts at the top of the scroll.
      await tester.pumpWidget(
        todayHost(store, connection: const ConnectionFailed(kBluetoothOff)),
      );
      await tester.pumpAndSettle();

      final header = tester.getRect(find.byType(TodayHeader));
      final body = tester.getRect(find.byType(Scaffold).first);
      expect(
        header.top - body.top,
        lessThan(24),
        reason:
            'a failing link used to open a full-width bar above this row; '
            'nothing may sit above the header now',
      );
    });

    testWidgets('there is no Sync now button anywhere on Today', (tester) async {
      await tester.pumpWidget(
        todayHost(store, connection: const ConnectionFailed(kBluetoothOff)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sync now'),
        findsNothing,
        reason: 'pull-to-refresh is the manual path; the button was the chrome',
      );
    });
  });

  group('EVERY UNHEALTHY STATE IS LOUD', () {
    for (final probe in unhealthyCases) {
      testWidgets('${probe.name} is a SENTENCE on the data-health card', (
        tester,
      ) async {
        await tester.pumpWidget(probe.card);
        await tester.pump();

        expect(find.textContaining(probe.cardText), findsOneWidget);
      });

      testWidgets('${probe.name}: EVERY alert it raises reaches the card', (
        tester,
      ) async {
        // Generic, on purpose. Naming the sentence proves this case; walking
        // `alerts` proves the NEXT one, which is the case nobody wrote a test
        // for. A fault classified loud and drawn nowhere fails right here, and
        // so does one whose id belongs to neither half — which is what a new
        // alert added without a surface would look like.
        await tester.pumpWidget(probe.card);
        await tester.pump();

        final loud = <String, HealthLine>{
          for (final line in dataHealthLines(
            now: now,
            push: probe.push,
            lastStrapSync: probe.lastStrapSync,
            signedIn: probe.signedIn,
          ))
            if (line.loud) line.id: line,
        };
        final links = <String>{
          for (final alert in probe.health.linkAlerts) alert.id,
        };
        expect(probe.health.alerts, isNotEmpty);
        for (final alert in probe.health.alerts) {
          if (links.contains(alert.id)) {
            // A radio fault: the card is the ONLY place its words exist.
            expect(
              find.text(alert.headline),
              findsOneWidget,
              reason: '${alert.id} has no health line and now no surface',
            );
            continue;
          }
          final line = loud[alert.id];
          expect(
            line,
            isNotNull,
            reason: '${alert.id} is in neither half — it can reach no surface',
          );
          expect(
            find.text(line!.text),
            findsOneWidget,
            reason: '${alert.id} is classified loud and drawn nowhere',
          );
        }
      });

      testWidgets('${probe.name} puts the ring in its attention state', (
        tester,
      ) async {
        await tester.pumpWidget(headerWith(probe.health));
        await tester.pump();

        expect(ringStateOf(probe.health), SyncRingState.needsAttention);
        expect(
          ringLabel(probe.health),
          contains(probe.health.alerts.first.headline),
          reason: 'the ring is four colours to anybody who cannot see them',
        );
      });
    }

    testWidgets('a link failure carries its remedy AND its freshness', (
      tester,
    ) async {
      // Nothing else on the screen says how to fix a radio. This is the half
      // that had no surface at all until the card took it.
      await tester.pumpWidget(unhealthyCases.first.card);
      await tester.pump();

      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(find.text('Last full sync 9 h ago.'), findsOneWidget);
      expect(find.text('Turn Bluetooth on and try again.'), findsOneWidget);
    });

    testWidgets('never-synced carries its remedy too', (tester) async {
      await tester.pumpWidget(unhealthyCases[1].card);
      await tester.pump();

      expect(
        find.text('Nothing has been read from your strap yet'),
        findsOneWidget,
      );
      expect(
        find.text('Pull down with the strap on your wrist and nearby.'),
        findsOneWidget,
      );
    });
  });
}
