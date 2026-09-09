/// Reading and writing the coach's conversations on this device.
///
/// The thread used to live only in a `keepAlive` provider, so it died with the
/// process. That showed up as a defect rather than a limitation: the owner asked
/// a question, the app was reinstalled, and an answer they had been charged one
/// of twenty for was gone with no record it had existed.
///
/// ## Every read and write carries the sign-in's scope
///
/// The same rule `CachedPayloads` follows, for the same reason. Without it a
/// second owner signing in on one handset reads the first owner's conversations
/// out of the local database — the isolation the server enforces, undone on the
/// client by a query that forgot to ask whose rows these were. `scope` is a
/// required argument on every method here rather than a field with a default,
/// so an unscoped call is a compile error and not a leak.
///
/// ## A turn is stored the moment it exists
///
/// Not on leaving the screen and not on a timer: the process can end at any
/// point, and the whole reason this exists is that an answer the owner paid for
/// must outlive it. `append` is called by the controller as each entry lands,
/// including a [CoachTrouble] — a question that failed still cost the owner an
/// attempt, and a history that quietly dropped the failures would be a record of
/// only the good days.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:healthee/data/coach/coach_answer.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/coach/coach_conversation.dart';

/// One conversation as the history list needs it: enough to draw a row.
class CoachThreadSummary {
  /// All fields come from the thread row; none is recomputed from its turns.
  const CoachThreadSummary({
    required this.id,
    required this.opening,
    required this.startedAt,
    required this.lastAt,
    required this.turns,
  });

  /// Its id.
  final String id;

  /// The first question asked, verbatim.
  final String opening;

  /// When it began.
  final DateTime startedAt;

  /// When it last moved.
  final DateTime lastAt;

  /// How many entries it holds.
  final int turns;
}

/// The device's record of what was asked and answered.
class CoachHistoryStore {
  /// Reads and writes through [store].
  const CoachHistoryStore(this._store);

  final LocalStore _store;

  /// Starts a thread, or updates the one already there.
  Future<void> open({
    required String scope,
    required String threadId,
    required String opening,
    required DateTime at,
  }) async {
    await _store
        .into(_store.coachThreads)
        .insertOnConflictUpdate(
          CoachThreadsCompanion.insert(
            scope: Value(scope),
            id: threadId,
            startedAt: at,
            lastAt: at,
            opening: opening,
          ),
        );
  }

  /// Appends one entry, and moves the thread's clock and count with it.
  ///
  /// The two writes are one transaction: a turn stored without its thread's
  /// count moving would make the history list disagree with the conversation it
  /// claims to summarise, and that disagreement is unrecoverable afterwards
  /// because neither side records which of them is stale.
  Future<void> append({
    required String scope,
    required String threadId,
    required int seq,
    required CoachEntry entry,
    required DateTime at,
  }) async {
    await _store.transaction(() async {
      await _store
          .into(_store.coachTurns)
          .insertOnConflictUpdate(
            CoachTurnsCompanion.insert(
              scope: Value(scope),
              threadId: threadId,
              seq: seq,
              kind: _kindOf(entry),
              payload: jsonEncode(_encode(entry)),
              at: at,
            ),
          );
      await (_store.update(
        _store.coachThreads,
      )..where((t) => t.scope.equals(scope) & t.id.equals(threadId))).write(
        CoachThreadsCompanion(lastAt: Value(at), turns: Value(seq + 1)),
      );
    });
  }

  /// Every conversation for [scope], most recently moved first.
  Future<List<CoachThreadSummary>> threads(String scope) async {
    final query = _store.select(_store.coachThreads)
      ..where((t) => t.scope.equals(scope))
      ..orderBy([(t) => OrderingTerm.desc(t.lastAt)]);
    final rows = await query.get();
    return <CoachThreadSummary>[
      for (final row in rows)
        CoachThreadSummary(
          id: row.id,
          opening: row.opening,
          startedAt: row.startedAt,
          lastAt: row.lastAt,
          turns: row.turns,
        ),
    ];
  }

  /// One conversation's entries, in the order they were added.
  ///
  /// A row whose `kind` no longer resolves is SKIPPED and the rest are returned.
  /// The alternative is throwing, which would make one unreadable turn cost the
  /// owner the whole conversation — and the unreadable case is exactly the one a
  /// future version of this app creates by adding a fourth kind.
  Future<List<CoachEntry>> entries({
    required String scope,
    required String threadId,
  }) async {
    final query = _store.select(_store.coachTurns)
      ..where((t) => t.scope.equals(scope) & t.threadId.equals(threadId))
      ..orderBy([(t) => OrderingTerm.asc(t.seq)]);
    final rows = await query.get();
    return <CoachEntry>[
      for (final row in rows)
        if (_decode(row.kind, row.payload) case final CoachEntry entry) entry,
    ];
  }

  /// Forgets one conversation and everything in it.
  Future<void> forget({required String scope, required String threadId}) async {
    await _store.transaction(() async {
      await (_store.delete(_store.coachTurns)
            ..where((t) => t.scope.equals(scope) & t.threadId.equals(threadId)))
          .go();
      await (_store.delete(
        _store.coachThreads,
      )..where((t) => t.scope.equals(scope) & t.id.equals(threadId))).go();
    });
  }
}

String _kindOf(CoachEntry entry) => switch (entry) {
  OwnerQuestion() => 'question',
  CoachReply() => 'reply',
  CoachTrouble() => 'trouble',
};

Map<String, Object?> _encode(CoachEntry entry) => switch (entry) {
  final OwnerQuestion q => <String, Object?>{'text': q.text},
  final CoachReply r => <String, Object?>{'answer': r.answer.toJson()},
  final CoachTrouble t => <String, Object?>{
    'message': t.message,
    'charge': t.charge.name,
    'resetsAt': t.resetsAt?.toIso8601String(),
  },
};

CoachEntry? _decode(String kind, String payload) {
  final Object? json = jsonDecode(payload);
  if (json is! Map<String, Object?>) {
    return null;
  }
  return switch (kind) {
    'question' => OwnerQuestion(json['text']! as String),
    'reply' => CoachReply(
      CoachAnswer.fromJson(json['answer']! as Map<String, Object?>),
    ),
    'trouble' => CoachTrouble(
      message: json['message']! as String,
      charge: CoachCharge.values.firstWhere(
        (CoachCharge c) => c.name == json['charge'],
        orElse: () => CoachCharge.unknown,
      ),
      resetsAt: switch (json['resetsAt']) {
        final String at => DateTime.tryParse(at),
        _ => null,
      },
    ),
    _ => null,
  };
}
