/// `GET /api/today` → drift → screen, including the day the network is gone.
///
/// Brief §7.4 makes offline readability a hard constraint, and the honest half
/// of it is the part these tests pin: a cached payload is rendered, and it is
/// rendered **as cached**. A silent fallback would let a phone that has been
/// offline since Tuesday draw a full screen of confident numbers about Tuesday
/// and call it today — the stale-as-current failure this product has shipped
/// once already.
///
/// The fixture is the committed contract snapshot, read from the repo, so the
/// cache is exercised against the real payload rather than a hand-built stub.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/today_repository.dart';

/// The snapshot, relative to `apps/mobile` — `flutter test`'s working directory.
const String _snapshotPath = '../../packages/contracts/snapshots/today.json';

final DateTime _fetchedAt = DateTime(2026, 8, 4, 9, 30);

String _snapshotJson() => File(_snapshotPath).readAsStringSync();

/// A transport that answers with [body], or fails when [body] is null.
class _StubTransport implements HttpClientAdapter {
  _StubTransport(this.body);

  String? body;
  int calls = 0;

  /// The query the last request carried — what `day=` was, or was not.
  Map<String, dynamic> lastQuery = const <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastQuery = options.queryParameters;
    final payload = body;
    if (payload == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline, for the test',
      );
    }
    return ResponseBody.fromString(
      payload,
      200,
      headers: const {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TodayRepository _repositoryOver(_StubTransport transport, LocalStore store) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.invalid',
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = transport;
  return TodayRepository(dio, store);
}

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  test('a fetch parses, and lands in the local tier on the way past', () async {
    final transport = _StubTransport(_snapshotJson());

    final view = await _repositoryOver(transport, store).load(now: _fetchedAt);

    expect(view.snapshot.date, '2026-07-31');
    expect(view.fromCache, isFalse);
    expect(view.fetchedAt, _fetchedAt);
    final row = await store.read(kTodayPayload, '2026-07-31');
    expect(row, isNotNull, reason: 'every good read is what makes the next '
        'offline launch readable');
  });

  test('THE DAY TRAVELS WITH THE REQUEST, AND IS ABSENT WHEN THERE IS NONE', () async {
    // `/api/today?day=D` is the whole server-side feature reaching the client
    // (`docs/AS_OF_DAY.md`). Drop it and every screen asks for the current day
    // while its header claims another — the header would be the only thing that
    // moved, which is a date control that lies.
    //
    // Absent rather than empty when no day is named: an omitted parameter is what
    // tells the server to answer for the owner's OWN today, in their timezone,
    // and `day=` is a malformed date it is right to refuse.
    final transport = _StubTransport(_snapshotJson());
    final repository = _repositoryOver(transport, store);

    await repository.load(now: _fetchedAt, day: '2026-07-29');
    expect(transport.lastQuery['day'], '2026-07-29');

    await repository.load(now: _fetchedAt);
    expect(transport.lastQuery.containsKey('day'), isFalse);
  });

  test('AN OFFLINE PAST DAY GETS THAT DAY\u2019S ROW OR NOTHING', () async {
    // The cache must not be a second route to the lie the endpoint refuses. A
    // past-day request that cannot reach the server falls back to the row filed
    // under THAT day; the newest row would be today's judgements under an older
    // date, which is exactly what the server declines to send.
    final transport = _StubTransport(_snapshotJson());
    final repository = _repositoryOver(transport, store);
    await repository.load(now: _fetchedAt); // fills the cache with 2026-07-31

    transport.body = null; // the network goes away

    await expectLater(
      repository.load(now: _fetchedAt, day: '2026-07-29'),
      throwsA(isA<DioException>()),
      reason: 'nothing is held for that day, and a neighbour is not an answer',
    );

    // The day we DO hold still answers, and still says it came from the cache.
    final held = await repository.load(now: _fetchedAt, day: '2026-07-31');
    expect(held.snapshot.date, '2026-07-31');
    expect(held.fromCache, isTrue);
  });

  test('AN OFFLINE READ IS SERVED, AND SAYS IT IS CACHED', () async {
    final transport = _StubTransport(_snapshotJson());
    final repository = _repositoryOver(transport, store);
    await repository.load(now: _fetchedAt);

    transport.body = null; // the network goes away
    final view = await repository.load(now: _fetchedAt.add(const Duration(days: 3)));

    expect(view.snapshot.date, '2026-07-31');
    expect(
      view.fromCache,
      isTrue,
      reason: 'a fallback that hides itself is the stale-as-current failure',
    );
    // The provenance is what lets the screen date what it is showing.
    expect(view.fetchedAt, _fetchedAt);
    expect(view.ageAt(_fetchedAt.add(const Duration(days: 3))).inDays, 3);
    expect(view.describesAnotherDay('2026-08-04'), isTrue);
  });

  test('offline with nothing cached is an ERROR, not an empty screen', () async {
    final transport = _StubTransport(null);

    await expectLater(
      _repositoryOver(transport, store).load(now: _fetchedAt),
      throwsA(isA<DioException>()),
      // "We could not answer" and "you have no data" are opposite messages. One
      // is our fault and worth retrying; the other would be a page of refusals
      // implying the owner's own data is missing.
      reason: 'an empty snapshot here would be the banned empty-means-failed',
    );
  });

  test('a body we cannot parse never becomes the thing we fall back to', () async {
    final transport = _StubTransport('"not an object"');

    await expectLater(
      _repositoryOver(transport, store).load(now: _fetchedAt),
      // dio wraps the cast failure, so it surfaces as a DioException like any
      // other unreachable server. That is the right *shape* — the screen shows
      // an error with a retry either way — and the log line names the real
      // cause, which is the part an operator needs.
      throwsA(isA<DioException>()),
    );
    expect(
      await store.read(kTodayPayload, '2026-07-31'),
      isNull,
      reason: 'the payload is parsed BEFORE it is stored; a cache full of '
          'unreadable JSON looks like coverage',
    );
  });

  test('the newest cached day wins, whatever order they arrived in', () async {
    final older = jsonDecode(_snapshotJson()) as Map<String, Object?>;
    final newer = Map<String, Object?>.from(older)..['date'] = '2026-08-01';
    await store.write(
      metric: kTodayPayload,
      day: '2026-08-01',
      payload: jsonEncode(newer),
      fetchedAt: _fetchedAt,
    );
    await store.write(
      metric: kTodayPayload,
      day: '2026-07-31',
      payload: jsonEncode(older),
      fetchedAt: _fetchedAt.subtract(const Duration(days: 1)),
    );

    final view = await _repositoryOver(_StubTransport(null), store).load();

    expect(view.snapshot.date, '2026-08-01');
  });
}
