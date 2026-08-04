/// The on-device 60-day tier: what the app can render before the network answers.
///
/// ## Why drift and not raw sqflite
///
/// Engineering Standards §3 requires typed models at the data boundary — "feature
/// code never reads raw `Map<String, dynamic>`". A hand-rolled sqflite layer hands
/// back exactly that map and asks every call site to remember the column names.
/// drift generates a row class per table and checks the queries at build time, so
/// the same guarantee the API models give us at the wire boundary holds at the
/// storage boundary too, and a renamed column is a compile error rather than a
/// null at 6 a.m.
///
/// ## What this table stores, and what it deliberately does not
///
/// One row per (day, metric): the **payload as the server sent it**, kept whole.
/// It is not a shredded copy of the server's schema — that would be a second
/// definition of every metric, which is the failure CLAUDE.md names first ("ONE
/// canonical definition per metric"). The cache holds bytes and dates; meaning
/// stays in [package:healthee/data/models] and is re-derived on read by the same
/// parser the network path uses. A cache that parses differently from the network
/// is a cache that can show a number the server never sent.
///
/// The 60-day horizon is a product decision from `docs/ARCHITECTURE.md`, enforced
/// in one place — [LocalStore.pruneBeyondHorizon] — for the same reason the
/// server keeps its freshness horizons in one module: a retention window that two
/// call sites can disagree about is a window nobody can state.
library;

import 'package:drift/drift.dart';
import 'package:healthee/data/store/connection.dart';
import 'package:healthee/data/store/push_reader.dart';
import 'package:healthee/data/store/strap_reader.dart';
import 'package:healthee/data/store/strap_writer.dart';
import 'package:healthee/data/store/tables.dart';

part 'local_store.g.dart';

/// How many days of history the device keeps. Beyond this the app asks the server.
const int localHorizonDays = 60;

/// One cached server payload, keyed by the day it describes and the metric it is.
///
/// ## `day` is TEXT, and that is the whole point
///
/// A server payload is a claim about an owner-local **calendar date** — never an
/// instant. Those are different types and this repo has shipped the confusion
/// twice. drift's `dateTime()` column makes the mistake for you: it stores a Unix
/// timestamp and hands it back in the *device's* local zone, so a date written as
/// `2026-06-01Z` reads back as `2026-06-01 05:30` in Asia/Kolkata and as
/// `2026-05-31 19:00` in America/Denver. The row would then be filed, compared and
/// pruned under a different day depending on where the phone was — and the test
/// suite would only catch it in one of the two timezones CI runs.
///
/// So the key is the ISO date string the server itself sent, stored verbatim.
/// `YYYY-MM-DD` sorts lexicographically exactly as it sorts chronologically, so
/// range queries and the horizon prune below work directly on it. There is no
/// conversion, therefore no zone, therefore nothing to get wrong.
@DataClassName('CachedPayload')
class CachedPayloads extends Table {
  /// The owner-local calendar date this payload describes, as `YYYY-MM-DD`.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  /// Which payload it is — `today`, `sleep`, `activity`, … (the endpoint's name).
  TextColumn get metric => text().withLength(min: 1, max: 64)();

  /// The response body, verbatim, as JSON text.
  TextColumn get payload => text()();

  /// When we received it. A genuine instant, so a DateTime is the right type
  /// here — and `storeDateTimeAsText` below keeps it in UTC across the round
  /// trip. It drives staleness display, never correctness.
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {day, metric};
}

/// The device's local tier — the server's cache AND the strap's own raw record.
///
/// ONE instance, provided by [localStoreProvider] — never constructed in a
/// widget. The two halves live in one database on purpose: they share the 60-day
/// horizon, and a retention window applied by two schedulers to two files is a
/// window nobody can state.
@DriftDatabase(
  tables: [
    CachedPayloads,
    StrapSamples,
    SleepSessions,
    StoredWorkouts,
    DeviceTotals,
    SyncMeta,
  ],
  daos: [StrapWriter, StrapReader, PushReader],
)
class LocalStore extends _$LocalStore {
  /// Opens the app's on-disk database.
  LocalStore() : super(openLocalStore());

  /// Opens a throwaway in-memory database. Tests only.
  LocalStore.memory() : super(openInMemory());

  /// Opens a database in a real file. Tests only — see [openFileAt] for the one
  /// kind of claim that needs it.
  LocalStore.at(String path) : super(openFileAt(path));

  @override
  int get schemaVersion => 3;

  /// v1 → v2 added the five raw-strap tables beside the payload cache.
  /// v2 → v3 added the per-row push marker to the four measurement tables.
  ///
  /// Additive, so each upgrade adds and touches nothing that exists. A phone
  /// that already holds cached server payloads keeps them; there is no path here
  /// that drops a table, because a migration that can delete health data is a
  /// migration that eventually will.
  ///
  /// The v3 columns arrive NULL on every existing row, which is the honest
  /// starting state: this build has never pushed, so nothing on a phone
  /// upgrading into it has reached the server. The first push sends the 60 days
  /// it holds, and the server upserts them by their own identity.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(strapSamples);
        await m.createTable(sleepSessions);
        await m.createTable(storedWorkouts);
        await m.createTable(deviceTotals);
        await m.createTable(syncMeta);
      }
      if (from < 3) {
        await m.addColumn(strapSamples, strapSamples.pushedAtMs);
        await m.addColumn(sleepSessions, sleepSessions.pushedAtMs);
        await m.addColumn(storedWorkouts, storedWorkouts.pushedAtMs);
        await m.addColumn(deviceTotals, deviceTotals.pushedAtMs);
      }
    },
  );

  /// Instants are stored as ISO-8601 text, which preserves UTC across the round
  /// trip. drift's default (a Unix timestamp read back in the device's local
  /// zone) is the same class of bug the `day` column's doc describes.
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);

  /// The cached payload for one day, or null when we have never stored it.
  ///
  /// Null means "we have not stored this", which is a different state from "the
  /// server sent an empty payload" — a caller must be able to tell them apart
  /// (Standards §1: "No data" and "operation failed" are different states).
  Future<CachedPayload?> read(String metric, String day) {
    final query = select(cachedPayloads)
      ..where((row) => row.metric.equals(metric) & row.day.equals(day))
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// The NEWEST cached payload of [metric], whatever day it describes.
  ///
  /// The offline read path. [read] answers "do we hold today's?", which is the
  /// wrong question after midnight with no network: the honest answer is not
  /// "nothing", it is "the last thing the server said, and here is its date".
  /// The row carries both, so the screen can date what it is showing rather than
  /// presenting yesterday as today — the stale-as-current failure this product
  /// exists to refuse.
  Future<CachedPayload?> readLatest(String metric) {
    final query = select(cachedPayloads)
      ..where((row) => row.metric.equals(metric))
      // `day` is `YYYY-MM-DD`, which sorts lexicographically exactly as it sorts
      // chronologically — the reason the column is TEXT at all.
      ..orderBy([(row) => OrderingTerm.desc(row.day)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Stores (or replaces) one day's payload. [day] is `YYYY-MM-DD`.
  Future<void> write({
    required String metric,
    required String day,
    required String payload,
    required DateTime fetchedAt,
  }) {
    return into(cachedPayloads).insertOnConflictUpdate(
      CachedPayloadsCompanion.insert(
        day: day,
        metric: metric,
        payload: payload,
        fetchedAt: fetchedAt,
      ),
    );
  }

  /// Drops every row dated before [oldestDayToKeep] (`YYYY-MM-DD`, inclusive),
  /// across **every** day-keyed table.
  ///
  /// The ONE place the horizon is applied, so the device's retention window
  /// cannot mean 60 days to one caller and 90 to another — and, now that there
  /// are six tables, cannot mean 60 days for cached payloads and forever for the
  /// samples beside them. Returns the total rows removed, so a caller can report
  /// it rather than pruning silently.
  ///
  /// [SyncMeta] is deliberately NOT pruned: its rows are bookkeeping about
  /// syncing, not dated measurements, and dropping the one-shot backfill flags
  /// would make a wide pass run again forever.
  ///
  /// Prefer [pruneBeyondHorizon], which computes the argument.
  Future<int> pruneBefore(String oldestDayToKeep) async {
    // Written out one table at a time rather than looped over a table list: a
    // loop would need the `day` column reached reflectively, and a table added
    // later without one would then prune nothing at runtime instead of failing
    // to compile here.
    final removed = await Future.wait([
      (delete(cachedPayloads)
            ..where((r) => r.day.isSmallerThanValue(oldestDayToKeep)))
          .go(),
      (delete(strapSamples)
            ..where((r) => r.day.isSmallerThanValue(oldestDayToKeep)))
          .go(),
      (delete(sleepSessions)
            ..where((r) => r.day.isSmallerThanValue(oldestDayToKeep)))
          .go(),
      (delete(storedWorkouts)
            ..where((r) => r.day.isSmallerThanValue(oldestDayToKeep)))
          .go(),
      (delete(deviceTotals)
            ..where((r) => r.day.isSmallerThanValue(oldestDayToKeep)))
          .go(),
    ]);
    return removed.reduce((a, b) => a + b);
  }

  /// Applies the 60-day horizon, given the owner's [today] (`YYYY-MM-DD`).
  ///
  /// The form callers should use: it takes the day the owner is living in and
  /// leaves no arithmetic at the call site, which is where a retention window
  /// quietly becomes two windows.
  Future<int> pruneBeyondHorizon(String today) =>
      pruneBefore(horizonStart(today));

}

/// The oldest calendar date the device keeps, given the owner's [today].
///
/// Separate from the query above so the arithmetic is testable without a
/// database, and so there is exactly one expression of "60 days back".
String horizonStart(String today) {
  final anchor = DateTime.parse(today);
  final start = DateTime.utc(anchor.year, anchor.month, anchor.day)
      .subtract(const Duration(days: localHorizonDays));
  return isoDay(start);
}

/// An instant rendered as the `YYYY-MM-DD` key these tables use.
///
/// Reads the calendar date **in whatever zone [day] carries**, which is the
/// behaviour both callers need and neither should have to think about: the
/// horizon arithmetic above works in UTC, while a strap sample's `DateTime` is
/// local wall-clock, and each is asking for its own day. Converting either one
/// to the other's zone is what files a row under the wrong date.
String isoDay(DateTime day) => day.toIso8601String().substring(0, 10);
