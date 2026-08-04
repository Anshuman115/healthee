/// Syncing over the session the foreground link is already holding.
///
/// Split out of `sync_engine_test.dart` on the 400-line gate, and it is the
/// right seam: everything here is about the path where the engine BORROWS a
/// session rather than opening one. Three things change on that path, and each
/// has a test below —
///
///   * the scan and the handshake are skipped, which is where `Sync now` gets
///     its speed while the app is open;
///   * the session is NOT closed, because whoever opened it closes it;
///   * the run rests on `Connected` rather than `Disconnected`, and only if the
///     session itself still says it is open.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_outcome.dart';

import '../ble/_fake_strap.dart';
import '../ble/strap_client_test.dart' show clientFor, healthyStrap, stressRounds;
import '../pairing/_pairing_fakes.dart';
import 'sync_engine_test.dart' show engineFor;

const String _today = '2026-08-04';

void main() {
  test('IS REUSED — no scan, no handshake, and it stays open', () async {
    late FakeStrap strap;
    final client = clientFor((_) => strap = healthyStrap(rounds: stressRounds()));
    final scanner = FakeStrapScanner();
    final wired = engineFor((_) => healthyStrap(), scanner: scanner, client: client);
    addTearDown(wired.store.close);
    final session = await client.connect();
    final seen = <StrapConnection>[];

    final outcome = await wired.engine.run(
      today: _today,
      onState: seen.add,
      session: session,
    );

    expect(outcome, isA<SyncComplete>());
    expect(
      scanner.asked,
      isEmpty,
      reason: 'a session we are talking over IS the presence check',
    );
    expect(seen.whereType<Scanning>(), isEmpty);
    expect(seen.whereType<Authenticating>(), isEmpty);
    expect(
      strap.closed,
      isFalse,
      reason: 'whoever opened the session closes it, and it was not us',
    );
    expect(session.isOpen, isTrue);
  });

  test('and the run RESTS ON CONNECTED, because the link is still open', () async {
    final client = clientFor((_) => healthyStrap(rounds: stressRounds()));
    final wired = engineFor((_) => healthyStrap(), client: client);
    addTearDown(wired.store.close);
    final session = await client.connect();
    final seen = <StrapConnection>[];

    await wired.engine.run(today: _today, onState: seen.add, session: session);

    expect(
      seen.last,
      isA<Connected>(),
      reason: 'landing on Disconnected would deny a session that is open',
    );
    expect((seen.last as Connected).since, session.authenticatedAt);
  });

  test('A DEAD SESSION IS NOT CLAIMED, even though one was handed in', () async {
    // The engine asks the session whether it is open; it does not remember that
    // it was given one. A radio that dropped between the link opening and the
    // sync starting looks exactly like this.
    final client = clientFor((_) => healthyStrap(hasActivityChannel: false));
    final wired = engineFor((_) => healthyStrap(), client: client);
    addTearDown(wired.store.close);
    final session = await client.connect();
    await session.close();
    final seen = <StrapConnection>[];

    await wired.engine.run(today: _today, onState: seen.add, session: session);

    expect(
      seen.whereType<Connected>(),
      isEmpty,
      reason: 'a closed session cannot license the word',
    );
    expect(seen.last, isA<Disconnected>());
  });

  test('the pull still stores what it pulled', () async {
    final client = clientFor((_) => healthyStrap(rounds: stressRounds()));
    final wired = engineFor((_) => healthyStrap(), client: client);
    addTearDown(wired.store.close);

    await wired.engine.run(
      today: _today,
      onState: (_) {},
      session: await client.connect(),
    );

    final rows = await wired.store.select(wired.store.strapSamples).get();
    expect(rows.map((row) => row.value).toList(), [40, 41, 43]);
  });
}
