/// The seam where HTTP becomes this app's own vocabulary.
///
/// `coach_sheet_test.dart` drives the sheet with [CoachRefusal] and
/// [CoachUnreachable] because that is the contract the controller catches. This
/// suite is the other half: that a real 402, a real 401 and a real dead socket
/// each become the right one of those, and that **no status code and no
/// `DioException` type ever reaches a sentence**.
///
/// The 402 body is the gate's own (`api/gate.py::_spent_body`): `limit`, `used`,
/// `resets_at`, `retry_after_s`, under FastAPI's `detail` wrapper. Parsing it is
/// what lets a refusal carry the instant the window reopens instead of a status.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/data/models/entitlement.dart';

/// A dio adapter that answers every request with one scripted reply.
class _OneReply implements HttpClientAdapter {
  _OneReply(this.status, this.body);

  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// An adapter that fails the way a dead network does.
class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'Failed host lookup',
  );

  @override
  void close({bool force = false}) {}
}

CoachClient _clientWith(HttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://healthee.example.test',
      // The app's own client raises non-2xx as a DioException, which is what the
      // conversion under test keys on. A stub that swallowed statuses would be
      // testing a client this app does not have.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = adapter;
  return CoachClient(dio);
}

void main() {
  test('the entitlement payload parses into a meter', () async {
    final client = _clientWith(
      _OneReply(200, const <String, Object?>{
        'premium': true,
        'status': 'active',
        'source': 'stripe',
        'plan': 'monthly',
        'expires_at': null,
        'locked': <String>[],
        'included': <Object?>[
          <String, Object?>{
            'feature': 'coach',
            'limit': 20,
            'used': 3,
            'remaining': 17,
            'window_days': 30,
            'resets_at': null,
            'retry_after_s': null,
          },
        ],
        'upgrade': 'https://example.test/upgrade',
      }),
    );

    final entitlement = await client.entitlement();
    final allowance = entitlement.allowanceFor(kCoachFeature)!;

    expect(entitlement.premium, isTrue);
    expect(allowance.remaining, 17);
    expect(allowance.limit, 20);
    expect(allowance.windowDays, 30);
    expect(
      allowance.resetsAt,
      isNull,
      reason: 'null while a slot is free — a reset instant beside "17 left" '
          'would read as a countdown that is not running',
    );
  });

  test('an empty `included` is NOT a meter reading zero', () async {
    // A free owner was not sold twenty of anything. Absent, never zero.
    final client = _clientWith(
      _OneReply(200, const <String, Object?>{
        'premium': false,
        'status': 'none',
        'locked': <String>['coach'],
        'included': <Object?>[],
        'upgrade': 'https://example.test/upgrade',
      }),
    );

    final entitlement = await client.entitlement();

    expect(entitlement.allowanceFor(kCoachFeature), isNull);
    expect(entitlement.isLocked(kCoachFeature), isTrue);
  });

  test('A 402 BECOMES A REFUSAL CARRYING THE RESET INSTANT', () async {
    final reopens = DateTime.utc(2026, 9, 1, 7);
    final client = _clientWith(
      _OneReply(402, <String, Object?>{
        'detail': <String, Object?>{
          'locked': true,
          'feature': 'coach',
          'limit': 20,
          'used': 20,
          'resets_at': reopens.toIso8601String(),
          'retry_after_s': 86400,
        },
      }),
    );

    await expectLater(
      client.ask(const <CoachTurn>[CoachTurn(role: 'user', content: 'hi')]),
      throwsA(
        isA<CoachRefusal>()
            .having((refusal) => refusal.message, 'message', contains('all 20'))
            .having((refusal) => refusal.resetsAt, 'resetsAt', reopens),
      ),
    );
  });

  test('a 402 with no limit is a hard lock, not a spent window', () async {
    final client = _clientWith(
      _OneReply(402, const <String, Object?>{
        'detail': <String, Object?>{'locked': true, 'feature': 'coach'},
      }),
    );

    await expectLater(
      client.ask(const <CoachTurn>[CoachTurn(role: 'user', content: 'hi')]),
      throwsA(
        isA<CoachRefusal>()
            .having((refusal) => refusal.message, 'message', contains('not included'))
            .having((refusal) => refusal.resetsAt, 'resetsAt', isNull),
      ),
    );
  });

  test('a 401 says what to do, and never says 401', () async {
    final client = _clientWith(_OneReply(401, const <String, Object?>{}));

    await expectLater(
      client.ask(const <CoachTurn>[CoachTurn(role: 'user', content: 'hi')]),
      throwsA(
        isA<CoachUnreachable>()
            .having((failure) => failure.message, 'message', contains('Sign in again'))
            .having((failure) => failure.message, 'message', isNot(contains('401'))),
      ),
    );
  });

  test('a dead socket says nothing was spent', () async {
    // The honest half of the sentence: the request never reached the gate, so
    // the owner's questions are untouched and the app can say so flatly.
    final client = _clientWith(_Offline());

    await expectLater(
      client.ask(const <CoachTurn>[CoachTurn(role: 'user', content: 'hi')]),
      throwsA(
        isA<CoachUnreachable>().having(
          (failure) => failure.message,
          'message',
          contains('nothing was spent'),
        ),
      ),
    );
  });

  test('an answer keeps its grade floor, its citations and its flags', () async {
    final client = _clientWith(
      _OneReply(200, const <String, Object?>{
        'reply': 'Sleep earlier [sleep_need_debt].',
        'citations': <String>['sleep_need_debt'],
        'grade_floor': 'Probable',
        'personal_findings': <String>[],
        'data_coverage': <String, Object?>{},
        'tool_calls': 2,
        'refused': false,
        'validated': true,
      }),
    );

    final answer = await client.ask(
      const <CoachTurn>[CoachTurn(role: 'user', content: 'hi')],
    );

    expect(answer.gradeFloor, 'Probable');
    expect(answer.citations, <String>['sleep_need_debt']);
    expect(answer.wasRefunded, isFalse);
  });

  test('a null grade floor is not a weak grade', () async {
    // `null` means nothing gradeable was cited. Defaulting it to the weakest
    // rank would be the app inventing a confidence statement.
    final client = _clientWith(
      _OneReply(200, const <String, Object?>{
        'reply': 'I cannot answer that.',
        'citations': <String>[],
        'grade_floor': null,
        'refused': true,
        'validated': true,
      }),
    );

    final answer = await client.ask(
      const <CoachTurn>[CoachTurn(role: 'user', content: 'hi')],
    );

    expect(answer.gradeFloor, isNull);
    expect(
      answer.wasRefunded,
      isTrue,
      reason: 'the server refunds a refusal, so the app must not count it spent',
    );
  });
}
