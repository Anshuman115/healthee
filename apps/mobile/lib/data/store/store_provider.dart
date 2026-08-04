/// The app's ONE [LocalStore], and the day it is asked about.
///
/// A database is a handle to a file: two instances mean two connection pools
/// over one SQLite file and two write paths that cannot see each other's
/// transactions. `keepAlive` for the same reason `apiClient` has it — a store
/// rebuilt per screen would reopen the file on every tab switch, against a
/// cold-start budget of 2 s (Standards §1).
///
/// Riverpod's provider lives here rather than in `local_store.dart` because that
/// file's `part` is drift's. Two generators cannot own one part file.
library;

import 'package:healthee/data/store/local_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'store_provider.g.dart';

/// The app's local database.
@Riverpod(keepAlive: true)
LocalStore localStore(Ref ref) {
  final store = LocalStore();
  ref.onDispose(store.close);
  return store;
}

/// The owner-local calendar date the app is showing, `YYYY-MM-DD`.
///
/// A provider rather than a `DateTime.now()` call inside the screen, for two
/// reasons that are really one: a test must be able to pin the day (a suite that
/// depends on the wall clock fails at midnight and passes on the retry), and
/// there must be exactly one answer to "what day is it" on a screen that files
/// nine things under it. Standards §3 bans string-literal user constants for the
/// same reason — a value the app reasons about belongs somewhere it can be
/// overridden.
///
/// **Local, deliberately.** The strap counts steps to ITS local midnight and the
/// store files rows by local calendar date, so the day the owner is living in is
/// the only one that lines up. `DateTime.now().toUtc()` here would show an
/// Asia/Kolkata owner yesterday's steps for the first five and a half hours of
/// every day.
@Riverpod(keepAlive: true)
String today(Ref ref) => isoDay(DateTime.now());
