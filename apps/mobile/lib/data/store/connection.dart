/// How the local store reaches SQLite — the one place that decides.
///
/// Split out of `local_store.dart` so the database's schema and its transport
/// have separate reasons to change (Standards §1). It is also the seam tests use:
/// [openInMemory] gives every test a private database, so two tests can never
/// corrupt each other through a shared file. (The server suite learned that the
/// expensive way — see the throwaway-container note in the repo's CI gotchas.)
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

/// The app's on-disk database, opened lazily on a background isolate.
///
/// `LazyDatabase` defers the `path_provider` call until the first query, so
/// constructing the store costs nothing on the cold-start path — the app's
/// budget there is 2 s to first meaningful paint (Standards §1).
QueryExecutor openLocalStore() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    return NativeDatabase.createInBackground(
      File('${directory.path}/healthee.sqlite'),
    );
  });
}

/// A private in-memory database. Tests only.
QueryExecutor openInMemory() => NativeDatabase.memory();

/// A database in a real file at [path]. Tests only.
///
/// [openInMemory] is the right seam for almost everything and should stay so.
/// This one exists for the claims where **the file is the point**: a cold start
/// is a new process reading bytes an earlier one wrote, and an in-memory
/// database cannot represent that at all — it would agree with any code, which
/// is precisely how a debounce that resets on every launch passes its own test.
QueryExecutor openFileAt(String path) => NativeDatabase(File(path));
