/// Where conversations with the coach are kept — on this phone, and nowhere else.
///
/// Until now a thread lived in a `keepAlive` Riverpod provider: it survived
/// leaving the screen and died with the process. That was visible as a defect
/// rather than a limitation — the owner asked a question, the app was reinstalled,
/// and an answer they had been CHARGED one of twenty for was gone with no record
/// it had ever existed.
///
/// ## Why the device and not the server
///
/// The server stores no conversation and is not asked to start. A coach turn is
/// the most personal text this product handles, and the honest place for it is
/// the phone that asked: `/api/coach` is stateless, so nothing has to be trusted
/// to forget it later. It also costs no schema on a box the owner is hosting
/// themselves.
///
/// The cost of that choice is stated rather than hidden: a new phone starts with
/// an empty history, and `horizon_prune` will age these out with everything else.
/// Neither is a surprise if it is written down.
///
/// ## `scope`, for the same reason `CachedPayloads` has one
///
/// Every row is namespaced to a sign-in. Without it a second owner signing in on
/// one handset would read the first owner's conversations out of the local
/// database — the isolation `0008` enforces on the server, undone on the client
/// by a table that forgot to ask whose rows these were.
library;

import 'package:drift/drift.dart';

/// One conversation, identified so its turns can find it.
class CoachThreads extends Table {
  /// Opaque sign-in namespace. No token or personal identifier is stored here.
  TextColumn get scope => text().withDefault(const Constant(''))();

  /// This thread's id — a UUID minted when the first question is asked.
  TextColumn get id => text()();

  /// When it began, and when it last moved. Both instants, stored as ISO-8601
  /// text by the database's `storeDateTimeAsText`, so a thread does not shift by
  /// a timezone when the owner travels.
  DateTimeColumn get startedAt => dateTime()();

  /// The last time a turn was added.
  DateTimeColumn get lastAt => dateTime()();

  /// The first question asked, verbatim — what the history list shows. Kept on
  /// the thread rather than re-read from the turns because a list of forty
  /// conversations should not have to load forty conversations to draw itself.
  TextColumn get opening => text()();

  /// How many turns it holds, for the same reason.
  IntColumn get turns => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {scope, id};
}

/// One turn in a conversation: what was asked, answered, or went wrong.
class CoachTurns extends Table {
  /// The sign-in that owns it.
  TextColumn get scope => text().withDefault(const Constant(''))();

  /// Which thread it belongs to.
  TextColumn get threadId => text()();

  /// Its position in that thread, from zero. Part of the key, so a turn cannot
  /// be stored twice and the order is the storage rather than a sort over it.
  IntColumn get seq => integer()();

  /// `question` | `reply` | `trouble` — the three cases of `CoachEntry`.
  ///
  /// Stored as text rather than an index: a sealed union that gains a fourth
  /// case must not silently renumber every row already written, and a name that
  /// no longer resolves is a loud failure instead of a quiet mis-read.
  TextColumn get kind => text()();

  /// The entry, as JSON. A reply carries its citations, its grade floor and its
  /// refund flags — everything `CoachAnswer` holds — because an answer stripped
  /// of what qualifies it is exactly the thing this app must not store.
  TextColumn get payload => text()();

  /// When it was added.
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {scope, threadId, seq};
}
