/// Turning a dead connection into a reason the owner can act on.
///
/// Extracted from `server_probe.dart` when a second client needed it: the probe
/// checks a token and `data/auth/device_token_client.dart` mints one, and both
/// have to tell a DNS failure from a refused socket from a rejected certificate.
/// Two copies of this mapping is two places for it to drift, on a screen whose
/// whole purpose is not to send somebody to their router when the answer is
/// their password.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:healthee/data/api/signin_failure.dart';

/// Maps a transport failure to a reason the owner can act on.
///
/// The wrapped cause is inspected BEFORE the dio type, because dio reports a
/// TLS handshake failure, a refused socket and a failed DNS lookup under the
/// same `connectionError` type — and those three send somebody to three
/// completely different places. Reading only `error.type` is exactly the
/// "a DioException type is not an error message" mistake.
ServerSignInFailure unreachableFailure(DioException error, String host) {
  return ServerUnreachable(reason: _reasonFor(error), host: host);
}

UnreachableReason _reasonFor(DioException error) {
  final cause = error.error;
  if (cause is HandshakeException || cause is CertificateException) {
    return UnreachableReason.tlsRejected;
  }
  if (error.type == DioExceptionType.badCertificate) {
    return UnreachableReason.tlsRejected;
  }
  if (cause is SocketException) {
    return _socketReason(cause);
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => UnreachableReason.timedOut,
    _ => UnreachableReason.unknown,
  };
}

/// dart:io folds "no such host" and "nothing is listening" into one class and
/// separates them by errno. 111/61/10061 are Linux/macOS/Windows ECONNREFUSED;
/// a lookup failure carries no address at all.
UnreachableReason _socketReason(SocketException error) {
  const refusedCodes = {111, 61, 10061};
  if (refusedCodes.contains(error.osError?.errorCode)) {
    return UnreachableReason.refused;
  }
  return error.address == null
      ? UnreachableReason.hostNotFound
      : UnreachableReason.refused;
}
