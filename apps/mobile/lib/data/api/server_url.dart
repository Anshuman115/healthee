/// The owner's server address, parsed and vetted before anything is sent to it.
///
/// A typed value rather than a `String`, because the two rules below have to
/// hold at every use and a bare string carries neither of them:
///
///  1. **A bearer token never goes over cleartext to a remote host.** Plain
///     `http://` is refused unless the host is loopback. This is checked here,
///     before the request exists, because by the time a response comes back the
///     token has already been on the wire in the clear.
///  2. **The stored base URL is normalised**, so the value the app talks to
///     tomorrow is byte-identical to the one the token was accepted by.
///
/// ## Why a missing scheme becomes `https://`
///
/// `Uri.parse('healthee.example.com:8765')` reads `healthee.example.com` as the
/// *scheme* and `8765` as the path — a silently wrong parse of a very ordinary
/// thing to type. So the scheme is detected with a regex and, when absent,
/// `https://` is prepended. That default only ever moves in the safe direction:
/// it can turn a working address into one that fails loudly on TLS, and can
/// never turn an encrypted one into a cleartext one.
library;

import 'dart:io';

import 'package:healthee/data/api/signin_failure.dart';
import 'package:meta/meta.dart';

/// `scheme://` at the start of a string. Anchored, so a path containing `://`
/// cannot satisfy it.
final RegExp _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

/// A vetted base URL for the Healthee API.
@immutable
class ServerUrl {
  const ServerUrl._(this.value, this.host);

  /// The normalised address, with no trailing slash. This is what is stored and
  /// what the interceptor puts on every request.
  final String value;

  /// The host alone, for log lines and failure copy. Never carries credentials.
  final String host;

  /// Parses [raw], or throws [ServerSignInException] with a named failure.
  ///
  /// Throwing rather than returning null: "this address is unusable" and "this
  /// address is cleartext" are different answers with different copy, and a null
  /// could carry neither (Standards §1 — a failure is never an empty value).
  static ServerUrl parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const ServerSignInException(
        MalformedServerUrl('nothing was entered'),
      );
    }

    final candidate = _scheme.hasMatch(trimmed) ? trimmed : 'https://$trimmed';
    final Uri uri;
    try {
      uri = Uri.parse(candidate);
    } on FormatException catch (error) {
      // The message names the position, never the input — an address is not a
      // secret, but quoting user input back into copy is a habit worth not having.
      throw ServerSignInException(
        MalformedServerUrl('it could not be read as a web address'
            '${error.offset == null ? '' : ' (character ${error.offset})'}'),
      );
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ServerSignInException(
        MalformedServerUrl('${uri.scheme} is not a web address scheme'),
      );
    }
    if (uri.host.isEmpty) {
      throw const ServerSignInException(MalformedServerUrl('it has no host'));
    }
    if (uri.userInfo.isNotEmpty) {
      // `https://user:pass@host` is a credential inside a URL, which is the one
      // place this app never puts one — it lands in proxy logs, in crash
      // reports and in the address bar of anything that renders it.
      throw const ServerSignInException(
        MalformedServerUrl('it carries a username or password before the host, '
            'and Healthee never puts a credential in a URL'),
      );
    }
    if (uri.scheme == 'http' && !isLoopbackHost(uri.host)) {
      throw ServerSignInException(CleartextServerUrl(uri.host));
    }

    return ServerUrl._(_normalise(uri), uri.host);
  }

  /// True for the hosts whose traffic never leaves this device.
  ///
  /// `InternetAddress.isLoopback` covers the whole `127.0.0.0/8` block and `::1`
  /// rather than the two spellings everyone remembers, and `localhost` is added
  /// because it is a name and not an address.
  ///
  /// **`10.0.2.2` is deliberately absent.** It is the Android emulator's alias
  /// for the host machine, and it is genuinely routed over the emulated NIC — it
  /// is a convenience, not a loopback, and a rule that lets a token onto a wire
  /// because a wire is short is not a rule.
  static bool isLoopbackHost(String host) {
    if (host == 'localhost') {
      return true;
    }
    // A bracketed IPv6 literal arrives from `Uri.host` unbracketed already, but
    // be defensive: the parser is not the only caller of this predicate.
    final bare = host.startsWith('[') && host.endsWith(']')
        ? host.substring(1, host.length - 1)
        : host;
    return InternetAddress.tryParse(bare)?.isLoopback ?? false;
  }

  /// The absolute URL for [path], e.g. `/api/entitlement`.
  Uri resolve(String path) => Uri.parse('$value$path');

  /// Scheme, authority and any path prefix; no trailing slash, no query, no
  /// fragment. A reverse proxy mounting the API under `/healthee` keeps that
  /// prefix; a stray `?` somebody pasted does not survive.
  static String _normalise(Uri uri) {
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${uri.scheme}://${uri.authority}$path';
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) => other is ServerUrl && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
