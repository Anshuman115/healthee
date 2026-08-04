/// How one push ended. The sibling of `sync/sync_outcome.dart`, same discipline.
///
/// ```text
///   sent       everything pending reached the server
///   partial    some pages landed, then one did not
///   failed     nothing landed
///   skipped    we did not try, and here is why
/// ```
///
/// [PushPartial] exists for the same reason [SyncPartial] does: a backlog is
/// pushed in pages, and a run that sent four of six pages moved real data even
/// though it did not finish. Calling that "failed" would understate it; calling
/// it "sent" would be the lie. Only [PushSent] may move "last complete push".
///
/// [PushSkipped] is the case a health surface must not colour as a fault. A
/// phone with nothing pending, or one that has never been given an API token,
/// is not broken — and a red badge over "you have not signed in" sends the owner
/// to look at their Bluetooth.
library;

import 'package:meta/meta.dart';

/// The result of one push attempt.
@immutable
sealed class PushOutcome {
  /// Base constructor. Use one of the cases.
  const PushOutcome();

  /// The id stored in [SyncMeta] and asserted on in tests.
  String get id;

  /// Whether this attempt may move "last complete push".
  bool get isComplete => this is PushSent;

  /// How many rows this attempt got onto the server.
  int get rowsSent => 0;

  /// A sentence for the sync-health line. Never empty.
  String get summary;
}

/// Everything that was pending reached the server.
final class PushSent extends PushOutcome {
  /// [rows] counts every row acknowledged, across all four kinds.
  const PushSent(this.rows);

  /// How many rows the server accepted.
  final int rows;

  @override
  String get id => 'sent';

  @override
  int get rowsSent => rows;

  @override
  String get summary =>
      rows == 0 ? 'Nothing new to send' : 'Sent $rows measurements';
}

/// Some pages landed and then one did not. The rest is still pending.
final class PushPartial extends PushOutcome {
  /// [rows] is what DID land; [reason] is why the run stopped.
  const PushPartial({required this.rows, required this.reason});

  /// How many rows the server accepted before it stopped.
  final int rows;

  /// Why the run stopped, in the owner's own words.
  final String reason;

  @override
  String get id => 'partial';

  @override
  int get rowsSent => rows;

  @override
  String get summary => 'Sent $rows measurements, then stopped — $reason';
}

/// Nothing reached the server.
final class PushFailed extends PushOutcome {
  /// [reason] names what went wrong, without inventing a remedy we do not have.
  const PushFailed(this.reason);

  /// Why nothing landed.
  final String reason;

  @override
  String get id => 'failed';

  @override
  String get summary => "Couldn't send to the server — $reason";
}

/// We did not try, and this is not a fault.
final class PushSkipped extends PushOutcome {
  /// [reason] says why — no token, nothing pending, no server configured.
  const PushSkipped(this.reason);

  /// Why the attempt was not made.
  final String reason;

  @override
  String get id => 'skipped';

  @override
  String get summary => reason;
}
