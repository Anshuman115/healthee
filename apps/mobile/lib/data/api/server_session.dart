/// Signing in to the owner's server, signing out of it, and what is held now.
///
/// The whole rule of this file is in [ServerSessionRepository.signIn]'s order:
///
/// ```text
///   parse the address   ──▶  cleartext and malformed die here, unsent
///   trim the token      ──▶  a pasted newline never becomes a 401
///   ask the server      ──▶  200 · 401 · unreachable, told apart
///   THEN store          ──▶  only a token the server itself accepted
/// ```
///
/// Storing before verifying is the tempting shortcut and it is what produces the
/// state this work package exists to end: an app that believes it is signed in,
/// serves 401s to every screen, and reports them as missing data.
///
/// ## Trimming is not tidiness
///
/// A token is copied out of a `.env` file or a terminal, and a copied secret
/// almost always carries a trailing newline. The server compares it with
/// `hmac.compare_digest` and the untrimmed value simply does not match — so the
/// owner gets "that token was refused", which is *true* and completely useless,
/// because the token on their clipboard is correct. One `.trim()`, in one place,
/// before the value is used or stored.
///
/// ## Nothing above this file ever sees the token
///
/// [ServerSessionStatus] carries whether there is a session and which server it
/// is for. It does not carry the token, and it must not: the same rule
/// `features/pairing/pairing_state.dart` states about the Zepp password applies
/// here, and for the same reason — a Riverpod observer that logs state
/// transitions would print it the day somebody adds one.
library;

import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_probe.dart';
import 'package:healthee/data/api/server_url.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_session.g.dart';

/// Whether this phone holds a server sign-in, and for which server.
///
/// **Never carries the token.** See the library docstring.
@immutable
class ServerSessionStatus {
  /// [baseUrl] is null exactly when [signedIn] is false.
  const ServerSessionStatus({required this.signedIn, this.baseUrl});

  /// Nothing is stored. The strap-only mode, which is fully supported.
  const ServerSessionStatus.signedOut() : this(signedIn: false);

  /// True when a verified token is in the keystore.
  final bool signedIn;

  /// The server that token was accepted by, for display.
  final String? baseUrl;

  /// The host alone, for a one-line summary. Null when signed out.
  String? get host => baseUrl == null ? null : Uri.parse(baseUrl!).host;
}

/// Verifies, stores and clears the owner's server sign-in.
class ServerSessionRepository {
  /// [credentials] is the keystore; [probe] is the one authenticated check.
  const ServerSessionRepository({required this.credentials, required this.probe});

  /// Where the session is kept.
  final Credentials credentials;

  /// The `GET /api/entitlement` check.
  final ServerProbe probe;

  /// Verifies [token] against [url] and stores both, or throws
  /// [ServerSignInException] with a named failure and stores **nothing**.
  ///
  /// Returns the address as it was normalised and stored, so a caller can show
  /// the owner what the app will actually talk to.
  Future<ServerUrl> signIn({required String url, required String token}) async {
    final address = ServerUrl.parse(url);
    final secret = token.trim();
    if (secret.isEmpty) {
      throw const ServerSignInException(MissingToken());
    }
    await probe.verify(url: address, token: secret);
    await credentials.setServerSession(baseUrl: address.value, token: secret);
    // The host, never the token, and never the whole address — a log line is
    // read by whoever has the device.
    AppLog.info('signin', 'signed in to ${address.host}');
    return address;
  }

  /// Clears the session from the keystore. The strap pairing is untouched:
  /// signing out of a server is not unpairing a watch, and a phone with no
  /// session still reads and stores everything the strap measured.
  Future<void> signOut() async {
    await credentials.forgetServerSession();
    AppLog.info('signin', 'signed out of the server; the strap pairing is kept');
  }

  /// What is held right now.
  ///
  /// A token with no address reads as **signed out**, the same way
  /// `PairingRepository.pairedStrap` treats half a pairing: a token we cannot
  /// say the server for is a token we cannot honestly claim a session with.
  Future<ServerSessionStatus> status() async {
    final token = await credentials.apiToken();
    final baseUrl = await credentials.apiBaseUrl();
    if (token == null || token.isEmpty || baseUrl == null || baseUrl.isEmpty) {
      return const ServerSessionStatus.signedOut();
    }
    return ServerSessionStatus(signedIn: true, baseUrl: baseUrl);
  }
}

/// The app's [ServerSessionRepository].
@Riverpod(keepAlive: true)
ServerSessionRepository serverSessionRepository(Ref ref) {
  return ServerSessionRepository(
    credentials: ref.watch(credentialsProvider),
    probe: ServerProbe(ServerProbe.dioFor()),
  );
}

/// Whether this phone is signed in, for anything that wants to say so.
///
/// `keepAlive` because the Today screen and the sign-in screen both watch it and
/// it is one keystore read; invalidated by the sign-in controller on both
/// transitions.
@Riverpod(keepAlive: true)
Future<ServerSessionStatus> serverSession(Ref ref) =>
    ref.watch(serverSessionRepositoryProvider).status();
