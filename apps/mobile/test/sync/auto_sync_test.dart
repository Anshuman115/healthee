/// The debounce, at its boundary and across a cold start.
///
/// Two of these are the whole feature and the rest are guards on them:
///
///   * a second automatic sync **inside** the window does not run, and one
///     **after** it does — asserted a millisecond either side, because a window
///     tested only in the middle is a window whose comparison could be `<`, `<=`
///     or `>=` and pass all three;
///   * the stamp **survives a cold start**. An in-memory one would reset on
///     every launch, which is exactly how "automatic, at most every fifteen
///     minutes" becomes "on every launch" while looking like it works.
///
/// The store is a real in-memory SQLite, so what is being tested is the actual
/// persisted key and not a fake that agrees with the code.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/auto_sync.dart';

final DateTime _synced = DateTime(2026, 8, 4, 12);

void main() {
  late LocalStore store;
  late DateTime clock;

  setUpAll(() {
    // The cold-start tests open a second database over the same file ON PURPOSE
    // — that is what a relaunch is. drift's warning is about accidentally doing
    // it concurrently; here the first is closed before the second opens.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    store = LocalStore.memory();
    clock = _synced;
  });
  tearDown(() async => store.close());

  /// A gate over the real store, reading [clock].
  AutoSyncGate gateOver(LocalStore over) => AutoSyncGate(
    lastCompleteSync: over.strapWriter.lastCompleteSync,
    now: () => clock,
  );

  /// Records a complete sync at [at], the way the engine does.
  Future<void> syncedAt(LocalStore over, DateTime at) => over.strapWriter
      .stampAttempt(at: at, outcomeId: 'complete', complete: true);

  Future<AutoSyncDecision> decide({bool linkHeld = true, bool busy = false}) =>
      gateOver(store).decide(linkHeld: linkHeld, busy: busy);

  group('the window', () {
    test('a phone that has never synced syncs immediately', () async {
      expect(await decide(), AutoSyncDecision.start);
    });

    test('A SECOND AUTO-SYNC INSIDE THE WINDOW IS SUPPRESSED', () async {
      await syncedAt(store, _synced);
      clock = _synced.add(const Duration(minutes: 14, seconds: 59));

      expect(
        await decide(),
        AutoSyncDecision.tooSoon,
        reason: 'an automatic sync on every foreground is a sync on every '
            'glance — seconds of radio on both devices for seconds of data',
      );
    });

    test('and one after it runs', () async {
      await syncedAt(store, _synced);
      clock = _synced.add(const Duration(minutes: 15, milliseconds: 1));

      expect(await decide(), AutoSyncDecision.start);
    });

    test('AT EXACTLY THE WINDOW it is still too soon', () async {
      // The boundary has one meaning, pinned here so a later `>=` is a failing
      // test rather than a fifteen-minute window that is sometimes fourteen.
      await syncedAt(store, _synced);
      clock = _synced.add(kAutoSyncWindow);

      expect(await decide(), AutoSyncDecision.tooSoon);
    });

    test('one millisecond past the window it runs', () async {
      await syncedAt(store, _synced);
      clock = _synced.add(kAutoSyncWindow + const Duration(milliseconds: 1));

      expect(await decide(), AutoSyncDecision.start);
    });

    test('a FAILED sync buys no silence at all', () async {
      // Only a complete sync moves `last_complete_sync_ms`. An owner returning
      // to a phone whose sync failed gets another attempt, which is the
      // direction to be wrong in.
      await store.strapWriter.stampAttempt(
        at: _synced,
        outcomeId: 'failed',
        complete: false,
      );
      clock = _synced.add(const Duration(minutes: 1));

      expect(await decide(), AutoSyncDecision.start);
    });
  });

  group('what else can refuse', () {
    test('no held session means nothing to sync over', () async {
      expect(await decide(linkHeld: false), AutoSyncDecision.noLink);
    });

    test('busy wins over everything, including a stale stamp', () async {
      // Checked first on purpose: the strap accepts one connection at a time.
      expect(await decide(busy: true, linkHeld: false), AutoSyncDecision.busy);
    });

    test('every refusal names itself, so a quiet foreground is diagnosable', () {
      expect(
        AutoSyncDecision.values.map((d) => d.name).toSet(),
        {'start', 'noLink', 'busy', 'tooSoon'},
      );
      expect(
        AutoSyncDecision.values.where((d) => d.shouldStart),
        [AutoSyncDecision.start],
      );
    });
  });

  test('THE STAMP SURVIVES A COLD START', () async {
    // The one that matters, and the one an in-memory database cannot prove:
    // a cold start is a new store reading bytes an earlier one wrote. An
    // in-memory debounce would be reset by it and would sync on every launch
    // while looking, from the inside, exactly like it was working.
    final directory = await Directory.systemTemp.createTemp('healthee_cold');
    addTearDown(() async => directory.delete(recursive: true));
    final path = '${directory.path}/healthee.sqlite';

    final firstLaunch = LocalStore.at(path);
    await syncedAt(firstLaunch, _synced);
    await firstLaunch.close();

    final relaunched = LocalStore.at(path);
    addTearDown(() async => relaunched.close());
    clock = _synced.add(const Duration(minutes: 1));

    expect(
      await gateOver(relaunched).decide(linkHeld: true, busy: false),
      AutoSyncDecision.tooSoon,
      reason: 'the stamp is in SQLite, not in a field on a notifier',
    );
  });

  test('and a cold start LONG after still syncs', () async {
    // The other half: persistence must not become a debounce that never lifts.
    final directory = await Directory.systemTemp.createTemp('healthee_cold');
    addTearDown(() async => directory.delete(recursive: true));
    final path = '${directory.path}/healthee.sqlite';

    final firstLaunch = LocalStore.at(path);
    await syncedAt(firstLaunch, _synced);
    await firstLaunch.close();

    final relaunched = LocalStore.at(path);
    addTearDown(() async => relaunched.close());
    clock = _synced.add(const Duration(hours: 3));

    expect(
      await gateOver(relaunched).decide(linkHeld: true, busy: false),
      AutoSyncDecision.start,
    );
  });
}
