/// Scaffolding for the sign-in suites: a scriptable server and a fake keystore.
///
/// Not a `*_test.dart` file, so `flutter test` never runs it as a suite.
///
/// **No real token appears anywhere in this directory.** Every secret used here
/// is an obvious sentinel that exists in no other file, which is exactly what
/// makes `signin_secrecy_test.dart`'s "this string never reaches a log" claim
/// mean something.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_probe.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/auth/device_token_client.dart';
import 'package:healthee/data/auth/identity_client.dart';

import '../pairing/_pairing_fakes.dart';

/// The sentinel token every sign-in test signs in with. Exists nowhere else.
const String kSentinelToken = 'S3NTINEL-API-TOKEN-4f19c7';

/// A body shaped like the real `/api/entitlement` reply, with nothing personal.
const String kEntitlementBody =
    '{"premium":false,"status":"free","source":"none","plan":null,'
    '"expires_at":null,"locked":["coach"],"included":[],'
    '"upgrade":"https://example.invalid/upgrade"}';

/// Builds the transport failure a scripted server throws instead of answering.
typedef DioExceptionBuilder = DioException Function(RequestOptions options);

/// One scripted reply from a server.
class ServerReply {
  /// [body] is returned verbatim.
  const ServerReply(this.status, {this.body = ''});

  /// A 200 carrying a plausible entitlement payload.
  const ServerReply.entitlement() : this(200, body: kEntitlementBody);

  /// HTTP status.
  final int status;

  /// Response body.
  final String body;
}

/// A dio adapter that answers with one reply, and records every request.
class ScriptedServer implements HttpClientAdapter {
  /// [reply] answers everything; [failWith] is thrown instead when set.
  ///
  /// [replies] answers each request IN TURN, for a flow that makes more than one
  /// — an identity sign-in verifies and then mints, and the case worth writing
  /// is the one where the first succeeds and the second does not. The last entry
  /// answers every request past the end of the list, so a script only has to
  /// name the calls it cares about.
  ScriptedServer({
    this.reply = const ServerReply.entitlement(),
    this.failWith,
    this.replies,
  });

  /// What to answer.
  ServerReply reply;

  /// One answer per request, in order. Null uses [reply] for all of them.
  final List<ServerReply>? replies;

  /// A transport failure to throw instead of answering.
  DioExceptionBuilder? failWith;

  /// Every request made, in order. Used to prove what was and was not sent.
  final List<RequestOptions> sent = [];

  /// Every request body, in order.
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
    final fail = failWith;
    if (fail != null) {
      throw fail(options);
    }
    final scripted = replies;
    if (scripted != null && scripted.isNotEmpty) {
      reply = scripted[sent.length > scripted.length
          ? scripted.length - 1
          : sent.length - 1];
    }
    // **With its content type.** Without one dio's JSON transformer leaves the
    // body a String, and a client that asks for `ResponseType.json` gets a
    // String where it expects a Map — so every parse branch reports "a reply
    // this app could not read" against a reply that was perfectly well formed.
    // The probe never noticed because it asks for plain text on purpose.
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A [ServerProbe] wired to [server], with the production dio configuration.
ServerProbe probeWith(ScriptedServer server) {
  final dio = ServerProbe.dioFor()..httpClientAdapter = server;
  return ServerProbe(dio);
}

/// A repository over a map-backed keystore and a scripted server.
///
/// [identity] and [devices] default to null — the shape of a build with no
/// identity provider, which is exactly what the pasted-token path is for. The
/// identity sign-in has its own fixtures in `identity_signin_test.dart`.
ServerSessionRepository repositoryWith(
  FakeSecretStore store,
  ScriptedServer server, {
  IdentityClient? identity,
  DeviceTokenClient? devices,
}) {
  return ServerSessionRepository(
    credentials: Credentials(store),
    probe: probeWith(server),
    identity: identity,
    devices: devices,
  );
}

/// The transport failure a dead DNS produces.
DioExceptionBuilder hostNotFound(String host) {
  return (options) => DioException.connectionError(
    requestOptions: options,
    reason: 'Failed host lookup',
    error: SocketException('Failed host lookup: $host'),
  );
}

/// The transport failure a machine with nothing listening produces.
DioExceptionBuilder connectionRefused() {
  return (options) => DioException.connectionError(
    requestOptions: options,
    reason: 'Connection refused',
    error: const SocketException(
      'Connection refused',
      osError: OSError('Connection refused', 111),
      address: null,
      port: 8765,
    ),
  );
}

/// The transport failure a bad certificate produces.
DioExceptionBuilder tlsRejected() {
  return (options) => DioException.connectionError(
    requestOptions: options,
    reason: 'handshake failed',
    error: const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
  );
}

/// The transport failure a server that accepts and never answers produces.
DioExceptionBuilder receiveTimeout() {
  return (options) => DioException.receiveTimeout(
    timeout: const Duration(seconds: 10),
    requestOptions: options,
  );
}
