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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
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
