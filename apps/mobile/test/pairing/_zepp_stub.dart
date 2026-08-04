/// A scriptable Zepp, so the pairing tests never touch the network.
///
/// Not a `*_test.dart` file, so `flutter test` does not run it — it is shared
/// scaffolding for `zepp_client_test.dart`, `pairing_secrecy_test.dart` and the
/// screen test.
///
/// ## About the fixtures
///
/// `test/fixtures/pairing/` holds three payloads. They are **shaped from the
/// proven reference's own constants** — `huami_token/constants.py` for the
/// redirect URI and `models.py` for which device fields are read — with every
/// secret replaced by an obvious placeholder. They are not captures from a real
/// account: this work package deliberately had no access to one, and asking for
/// the owner's Zepp password to make a nicer fixture would have contradicted the
/// thing it is building. What they pin is the SHAPE the parser must handle and
/// the FIELD NAMES it must read, which is what a shape change would break.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:healthee/data/pairing/zepp_client.dart';

/// Reads a fixture from `test/fixtures/pairing/`.
String fixture(String name) =>
    File('test/fixtures/pairing/$name').readAsStringSync().trim();

/// One scripted reply.
class StubReply {
  /// [body] is returned verbatim; [headers] are lower-cased response headers.
  const StubReply(this.status, {this.body = '', this.headers = const {}});

  /// A 3xx carrying a `Location`, which is how step 1 answers.
  factory StubReply.redirect(String location) =>
      StubReply(303, headers: {'location': location});

  /// HTTP status.
  final int status;

  /// Response body.
  final String body;

  /// Response headers.
  final Map<String, String> headers;
}

/// A dio adapter that answers from a script keyed by URL substring.
class StubAdapter implements HttpClientAdapter {
  /// [replies] maps a substring of the request URL to its reply. A request that
  /// matches nothing throws, because a silently-unmatched call in a test is a
  /// test that proves less than it appears to.
  StubAdapter(this.replies);

  /// URL substring → reply.
  final Map<String, StubReply> replies;

  /// Every request the client made, in order. Used to prove what was sent.
  final List<RequestOptions> sent = [];

  /// The raw request bodies, in order.
  final List<Uint8List> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      bodies.add(Uint8List.fromList(chunks.expand((chunk) => chunk).toList()));
    }

    final url = options.uri.toString();
    for (final entry in replies.entries) {
      if (url.contains(entry.key)) {
        return ResponseBody.fromString(
          entry.value.body,
          entry.value.status,
          headers: entry.value.headers.map(
            (name, value) => MapEntry(name, [value]),
          ),
        );
      }
    }
    throw StateError('no stubbed reply for $url');
  }

  @override
  void close({bool force = false}) {}
}

/// An adapter that fails the way a dead network does.
class OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Failed host lookup: api-user-us2.zepp.com',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A [ZeppClient] wired to [adapter].
ZeppClient clientWith(HttpClientAdapter adapter) {
  final dio = ZeppClient.dioFor()..httpClientAdapter = adapter;
  return ZeppClient(dio);
}

/// The happy path: a redirect with tokens, a login, and three devices.
StubAdapter happyPathAdapter() => StubAdapter({
  '/v2/registrations/tokens': StubReply.redirect(fixture('zepp_token_redirect.txt')),
  '/v2/client/login': StubReply(200, body: fixture('zepp_login.json')),
  '/devices': StubReply(200, body: fixture('zepp_devices.json')),
});
