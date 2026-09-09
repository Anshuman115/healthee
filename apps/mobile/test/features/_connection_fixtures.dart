/// The connection-surface fixtures, shared by the two suites that split off it.
///
/// Extracted on the second use (Standards §1). The enumeration of unhealthy
/// states is the load-bearing thing in both files — one asks whether each one
/// reaches a surface, the other asks whether any of them can come out the quiet
/// side — and two copies of a table whose whole job is to be exhaustive is two
/// tables that can disagree about what "every state" means.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/prune_report.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/health_lines.dart';
import 'package:healthee/data/sync/sync_failure.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';

import '_today_host.dart';

/// A named radio failure with a headline and a remedy of its own.
const SyncFailure kBluetoothOff = SyncFailure(
  headline: 'Bluetooth is off',
  remedy: 'Turn Bluetooth on and try again.',
  code: 'bluetooth_off',
  source: 'test',
);

/// The facts one case is built from, so the classifier and the card are fed the
/// SAME inputs rather than a `ConnectionHealth` and a hand-matched card.
///
/// This is the join the deleted strip used to make implicitly. Handing the
/// health object to the classifier assertion and a different set of arguments to
/// the widget would let the two agree about a state neither of them has.
class ConnectionCase {
  /// One state of the world, named.
  const ConnectionCase({
    required this.name,
    required this.cardText,
    required this.link,
    this.signedIn = true,
    this.push,
    this.lastStrapSync,
  });

  /// How the case reads in a test name.
  final String name;

  /// The sentence that MUST appear on the card the owner will read.
  ///
  /// Deliberately not the alert's headline for a data fault: the two surfaces
  /// are a **title and its paragraph**, so the card carries `HealthLine.text`
  /// and the ring announces `HealthLine.headline`. A test that expected the
  /// headline on the card would be asserting the surfaces say the same thing,
  /// which is the design they were built to avoid.
  final String cardText;

  /// The pinned link state.
  final StrapConnection link;

  /// Whether this phone holds a server session.
  final bool signedIn;

  /// What the last push did, if anything.
  final PushStamp? push;

  /// When the strap was last read completely.
  final DateTime? lastStrapSync;

  /// The classification, from these facts.
  ConnectionHealth get health => connectionHealth(
    link: link,
    now: now,
    push: push,
    signedIn: signedIn,
    lastStrapSync: lastStrapSync,
  );

  /// The card, fed exactly the facts the classifier was fed.
  Widget get card => MaterialApp(
    // The app's real theme: `context.colors` reads the `HealtheeColors`
    // extension and a bare `MaterialApp` has none, which fails as a null check
    // rather than as anything about the card.
    theme: AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: DataHealthSection(
          connection: health,
          push: push,
          signedIn: signedIn,
          lastStrapSync: lastStrapSync,
          now: now,
        ),
      ),
    ),
  );
}

/// A phone with nothing wrong: a sync finished four minutes ago, a session is
/// held, the push is clear.
ConnectionHealth healthyConnection() => connectionHealth(
  link: Disconnected(
    lastCompleteSync: now.subtract(const Duration(minutes: 4)),
  ),
  now: now,
  push: const PushStamp.never(),
  signedIn: true,
  lastStrapSync: now.subtract(const Duration(minutes: 4)),
);

/// Every state that MUST be loud, with the sentence a surface has to carry.
///
/// A list rather than six test bodies, because the point is the enumeration:
/// adding a failure state without adding it here is the mistake this design is
/// exposed to, and a table makes the omission visible in review.
final List<ConnectionCase> unhealthyCases = <ConnectionCase>[
  ConnectionCase(
    name: 'the strap could not be reached',
    cardText: 'Bluetooth is off',
    link: ConnectionFailed(
      kBluetoothOff,
      lastCompleteSync: now.subtract(const Duration(hours: 9)),
    ),
    lastStrapSync: now.subtract(const Duration(hours: 9)),
  ),
  const ConnectionCase(
    name: 'nothing has ever been read from the strap',
    cardText: 'Nothing has been read from your strap yet',
    link: Disconnected(),
  ),
  ConnectionCase(
    name: 'this phone is not signed in',
    cardText: 'This phone is not signed in to a Healthee server',
    link: Disconnected(lastCompleteSync: now),
    signedIn: false,
    lastStrapSync: now,
  ),
  ConnectionCase(
    name: 'the push is faulted',
    cardText: "The last attempt to send your data didn't finish",
    link: Disconnected(lastCompleteSync: now),
    lastStrapSync: now,
    push: PushStamp(
      lastAttempt: now,
      outcomeId: 'transport',
      failureReason: 'the server closed the connection',
      pendingRows: 900,
    ),
  ),
  ConnectionCase(
    name: 'the strap has gone unread past its horizon',
    cardText: 'Your strap was last read',
    link: Disconnected(
      lastCompleteSync: now.subtract(kStrapHorizonWarning * 2),
    ),
    lastStrapSync: now.subtract(kStrapHorizonWarning * 2),
  ),
  ConnectionCase(
    name: 'measurements were destroyed before they were sent',
    cardText: '4210 measurements recorded up to 2025-08-04',
    link: Disconnected(lastCompleteSync: now),
    lastStrapSync: now,
    push: PushStamp(
      lastAttempt: now,
      pendingRows: 0,
      outcomeId: 'pruned',
      loss: const UnsentLoss(rows: 4210, throughDay: '2025-08-04'),
    ),
  ),
];

/// The header row on its own, with one classification.
Widget headerWith(ConnectionHealth? health) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: TodayHeader(
      date: '2026-08-04',
      now: now,
      health: health,
      onOpenProfile: () {},
    ),
  ),
);
