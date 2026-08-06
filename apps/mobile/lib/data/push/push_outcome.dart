/// How one push ended. The sibling of `sync/sync_outcome.dart`, same discipline.
///
/// ```text
///   sent          everything pending reached the server
///   paused        a page cap was reached; real data landed, the rest follows
///   interrupted   some pages landed, then the transport died
///   failed        nothing landed
///   skipped       we did not try, and here is why
/// ```
///
/// ## Why "paused" and "interrupted" are two cases and not one
///
/// They used to be one — `PushPartial` — and that single type meant two opposite
/// things: *"the transport died after N rows"* and *"I hit my own page cap and
/// will continue."* The first is a fault. The second is the design working
/// exactly as `push_service.dart` describes it.
///
/// Collapsed together, the health card read **"The last attempt to send your
/// data didn't finish"** over a completely successful, deliberate pause — this
/// product's own honesty contract pointed at itself and getting it wrong. The
/// fix is in the type rather than in the wording, because a wording fix would
/// have had to re-derive the distinction from a reason string at the render
/// site, where nothing can check it.
///
/// [isFault] is abstract for the same reason: a case added later cannot forget
/// to answer the one question every health surface asks of this union.
///
/// [PushSkipped] is the other case a health surface must not colour as a fault.
/// A phone with nothing pending, or one that has never been given an API token,
/// is not broken — and a red badge over "you have not signed in" sends the owner
/// to look at their Bluetooth.
library;

import 'package:meta/meta.dart';

/// The ids stored in [SyncMeta] and read back by [PushStamp].
///
/// Constants rather than literals because they cross a persistence boundary:
/// a mistyped one reads back as an outcome nobody wrote and renders as silence.
///
/// **`partial` is gone and is deliberately not listed.** A store written by an
/// older build can still hold it; it has a failure reason beside it, so it is
/// read as a fault. That is the safe direction to be wrong in, and it clears on
/// the next push.
abstract final class PushOutcomeId {
  /// Everything pending reached the server.
  static const String sent = 'sent';

  /// A page cap was reached. Not a fault.
  static const String paused = 'paused';

  /// Pages landed, then the transport died. A fault.
  static const String interrupted = 'interrupted';

  /// Nothing landed. A fault.
  static const String failed = 'failed';

  /// We did not try. Not a fault.
  static const String skipped = 'skipped';
}

/// The result of one push attempt.
@immutable
sealed class PushOutcome {
  /// Base constructor. Use one of the cases.
  const PushOutcome();

  /// The id stored in [SyncMeta] and asserted on in tests.
  String get id;

  /// Whether this attempt may move "last complete push".
  bool get isComplete => this is PushSent;

  /// Whether this is something going wrong, as opposed to something working.
  ///
  /// The one question every health surface asks. Abstract on purpose — see the
  /// library docstring.
  bool get isFault;

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
  String get id => PushOutcomeId.sent;

  @override
  bool get isFault => false;

  @override
  int get rowsSent => rows;

  @override
  String get summary =>
      rows == 0 ? 'Nothing new to send' : 'Sent $rows measurements';
}

/// A page cap was reached with rows still pending. **Not a fault.**
///
/// Every page this run attempted was accepted; the run stopped because
/// `push_service.dart` bounds its own loops rather than trusting a marker it
/// does not verify. The rest goes out on the next sync, which is now automatic.
final class PushPaused extends PushOutcome {
  /// [rows] is what landed; [reason] says why the run stopped here.
  const PushPaused({required this.rows, required this.reason});

  /// How many rows the server accepted before the cap.
  final int rows;

  /// Why it stopped, in the owner's own words. Not a failure sentence.
  final String reason;

  @override
  String get id => PushOutcomeId.paused;

  @override
  bool get isFault => false;

  @override
  int get rowsSent => rows;

  @override
  String get summary => 'Sent $rows measurements — $reason';
}

/// Some pages landed and then the transport died. The rest is still pending.
final class PushInterrupted extends PushOutcome {
  /// [rows] is what DID land; [reason] is what went wrong.
  const PushInterrupted({required this.rows, required this.reason});

  /// How many rows the server accepted before it stopped.
  final int rows;

  /// What went wrong, in the owner's own words.
  final String reason;

  @override
  String get id => PushOutcomeId.interrupted;

  @override
  bool get isFault => true;

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
  String get id => PushOutcomeId.failed;

  @override
  bool get isFault => true;

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
  String get id => PushOutcomeId.skipped;

  @override
  bool get isFault => false;

  @override
  String get summary => reason;
}
