/// Signing in to the owner's server, signing out of it, and what is held now.
///
/// The whole rule of this file is the ORDER of its two sign-ins:
///
/// ```text
///   parse the address   ──▶  cleartext and malformed die here, unsent
///   prove who you are   ──▶  Supabase refuses a wrong password, offline
///   ask the server      ──▶  200 · 401 · 403 · unreachable, told apart
///   mint this device    ──▶  the long-lived credential /ingest/* takes
///   THEN store          ──▶  only a credential the server itself issued
/// ```
///
/// Storing before verifying is the tempting shortcut and it is what produces the
/// state this work package exists to end: an app that believes it is signed in,
/// serves 401s to every screen, and reports them as missing data.
///
/// ## Two ways in, and only one of them has a future
///
/// [ServerSessionRepository.signIn] takes an email and a password, proves them
/// against the identity provider, and comes back with a device token minted for
/// this phone alone. That is the one that isolates owners from each other.
///
/// [ServerSessionRepository.signInWithToken] pastes a credential the owner was
/// given. It exists because it is the only thing this app could do before, and
/// the credential it accepts is the shared `REALTIME_INGEST_TOKEN` — a key to
/// ONE tenant with no identity attached to it. **It must not outlive the
/// transition.** Handing that string to a second person hands them the first
/// person's health record; the server's own `core/config.py` refuses to boot
/// with it set beside open signups, and `docs/MULTI_USER.md` section 4.4a names
/// its removal condition. Delete this method when that secret goes.
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
import 'package:healthee/data/api/stored_server_session.dart';
import 'package:healthee/data/auth/device_token_client.dart';
import 'package:healthee/data/auth/identity_client.dart';
import 'package:healthee/data/auth/identity_providers.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_session.g.dart';

/// Whether this phone holds a server sign-in, and for which server.
///
/// **Never carries the token.** See the library docstring.
@immutable
class ServerSessionStatus {
  /// [baseUrl] is null exactly when [signedIn] is false.
  const ServerSessionStatus({
    required this.signedIn,
    this.baseUrl,
    this.rejected = false,
  });

  /// Nothing is stored. The strap-only mode, which is fully supported.
  const ServerSessionStatus.signedOut() : this(signedIn: false);

  /// True when a verified credential is in the keystore.
  final bool signedIn;

  /// The server that credential was accepted by, for display.
  final String? baseUrl;

  /// True once the server has rejected this session with a 401.
  ///
  /// **A third state, not a second flavour of signed out.** Something IS stored
  /// and the address is still known, so the screen can say "your session ended,
  /// sign in again" with the field already filled — rather than the blank form
  /// that clearing would produce. And it is not `signedIn: false`, because the
  /// two want different words: one is a choice the owner made and the other is
  /// something that happened to them.
  final bool rejected;

  /// The host alone, for a one-line summary. Null when signed out.
  String? get host => baseUrl == null ? null : Uri.parse(baseUrl!).host;
}

/// Verifies, stores and clears the owner's server sign-in.
class ServerSessionRepository {
  /// [credentials] is the keystore; [probe] is the one authenticated check;
  /// [identity] and [devices] are null on a build with no identity provider.
  ServerSessionRepository({
    required this.credentials,
    required this.probe,
    required this.identity,
    required this.devices,
  });

  /// Where the session is kept.
  final Credentials credentials;

  /// The `GET /api/entitlement` check.
  final ServerProbe probe;

  /// Proves who the owner is. Null when this build has no provider.
  final IdentityClient? identity;

  /// Mints this phone's ingest credential. Null when [identity] is.
  final DeviceTokenClient? devices;

  /// Signs in with an email and a password, and mints this device's token.
  ///
  /// Throws [ServerSignInException] with a named failure and stores **nothing**
  /// at every step. Returns the address as normalised and stored, so a caller
  /// can show the owner what the app will actually talk to.
  ///
  /// ## The order is the design
  ///
  /// The identity provider goes first because it is the only step that can say
  /// "that password is wrong" — and it says it without this server being
  /// involved at all, so a typo never looks like a server fault. Then the server
  /// is asked, with the JWT, which is where an uninvited email meets the signup
  /// gate and gets a 403 that means something specific. Only then is a device
  /// token minted, and only then is anything written down.
  ///
  /// ## A signed-in identity with no stored session is a real state
  ///
  /// If minting fails, the owner IS signed in to Supabase and this phone has no
  /// server session — which is correct and recoverable: pressing sign in again
  /// re-uses the live identity and retries the mint. Signing them back out to
  /// "clean up" would throw away a proven credential to make a failure tidier.
  Future<ServerUrl> signIn({
    required String url,
    required String email,
    required String password,
    String? deviceLabel,
  }) => _connect(
    url: url,
    email: email,
    password: password,
    deviceLabel: deviceLabel,
    create: false,
  );

  /// Creates the account, then does everything [signIn] does.
  ///
  /// The ONLY difference is the first call. Everything after it — the server
  /// check that trips the invite gate, the mint, the write — is shared, because
  /// a new owner and a returning one need exactly the same things to be true
  /// before this phone can claim to be signed in.
  ///
  /// ⚠ Creating an account here does NOT mean this server will serve it. The
  /// identity provider and the deployment are separate gates and the second one
  /// is ours: an email that is not on `SIGNUP_ALLOWLIST` gets a real Supabase
  /// account and a 403 from `/api/*`, reported as [ServerRefusedThisAccount].
  /// That is the design — `MULTI_USER.md` section 4.4b — and not a bug to route
  /// around: the server is the trust boundary, never a dashboard toggle.
  Future<ServerUrl> createAccount({
    required String url,
    required String email,
    required String password,
    String? deviceLabel,
  }) => _connect(
    url: url,
    email: email,
    password: password,
    deviceLabel: deviceLabel,
    create: true,
  );

  /// Proves an identity — new or returning — and connects this phone to [url].
  Future<ServerUrl> _connect({
    required String url,
    required String email,
    required String password,
    required String? deviceLabel,
    required bool create,
  }) async {
    final address = ServerUrl.parse(url);
    final auth = identity;
    final minter = devices;
    if (auth == null || minter == null) {
      throw const ServerSignInException(IdentityNotConfigured());
    }
    final trimmed = email.trim();
    if (create) {
      await auth.signUp(email: trimmed, password: password);
    } else {
      await auth.signIn(email: trimmed, password: password);
    }
    final jwt = await auth.accessToken();
    if (jwt == null) {
      // Signing in and immediately having no token is not a credential problem;
      // it is the provider having accepted and returned nothing usable.
      throw const ServerSignInException(IdentityUnreachable());
    }
    // With the JWT, because `/api/*` takes no other credential — and because
    // this is the call that trips the server's signup gate for an uninvited
    // email, which `ServerProbe` reports as its own named failure.
    await probe.verify(url: address, token: jwt);
    final deviceToken = await minter.mint(
      url: address,
      jwt: jwt,
      label: deviceLabel,
    );
    await credentials.setServerSession(
      baseUrl: address.value,
      token: deviceToken,
      kind: StoredCredentialKind.device,
    );
    rejected = false;
    // The host, never a credential, and never the whole address — a log line is
    // read by whoever has the device.
    AppLog.info('signin', 'signed in to ${address.host}');
    return address;
  }

  /// Verifies a PASTED [token] against [url] and stores both. ⛔ TRANSITIONAL.
  ///
  /// The credential this accepts is the shared `REALTIME_INGEST_TOKEN`: one
  /// string, no identity, and a key to one tenant's entire health record. It is
  /// here because it is the only thing this app could do before Supabase sign-in
  /// existed, and it goes when that secret does — see the library docstring.
  Future<ServerUrl> signInWithToken({
    required String url,
    required String token,
  }) async {
    final address = ServerUrl.parse(url);
    final secret = token.trim();
    if (secret.isEmpty) {
      throw const ServerSignInException(MissingToken());
    }
    await probe.verify(url: address, token: secret);
    await credentials.setServerSession(
      baseUrl: address.value,
      token: secret,
      kind: StoredCredentialKind.shared,
    );
    rejected = false;
    AppLog.info('signin', 'signed in to ${address.host} with a pasted token');
    return address;
  }

  /// Clears the session from the keystore. The strap pairing is untouched:
  /// signing out of a server is not unpairing a watch, and a phone with no
  /// session still reads and stores everything the strap measured.
  Future<void> signOut() async {
    // The identity session goes FIRST. If the keystore write failed after the
    // identity was already cleared the app would hold a server session it could
    // not authenticate — whereas this order leaves, at worst, a signed-out
    // identity with a stored session, which the next request resolves into a
    // 401 and a prompt to sign in. Neither is good; only one of them is quiet.
    await identity?.signOut();
    await credentials.forgetServerSession();
    rejected = false;
    AppLog.info(
      'signin',
      'signed out of the server; the strap pairing is kept',
    );
  }

  /// True once a 401 has been seen on this session; cleared by a new sign-in.
  ///
  /// Held in the repository rather than in the keystore on purpose: it is a
  /// fact about the RUNNING app, not about the phone. Persisting it would mean
  /// a restart still believed a credential was dead after the operator fixed
  /// whatever rejected it, and the way to find out is to make one request.
  bool rejected = false;

  /// What is held right now.
  ///
  /// A token with no address reads as **signed out**, the same way
  /// `PairingRepository.pairedStrap` treats half a pairing: a token we cannot
  /// say the server for is a token we cannot honestly claim a session with.
  Future<ServerSessionStatus> status() async {
    final session = await credentials.serverSession();
    if (session == null) return const ServerSessionStatus.signedOut();
    return ServerSessionStatus(
      signedIn: true,
      baseUrl: session.baseUrl,
      rejected: rejected,
    );
  }
}

/// The app's [ServerSessionRepository].
@Riverpod(keepAlive: true)
ServerSessionRepository serverSessionRepository(Ref ref) {
  final identity = ref.watch(identityClientProvider);
  return ServerSessionRepository(
    credentials: ref.watch(credentialsProvider),
    probe: ServerProbe(ServerProbe.dioFor()),
    identity: identity,
    // Together or neither: a mint has nothing to authenticate with when there
    // is no identity to sign in against.
    devices: identity == null
        ? null
        : DeviceTokenClient(DeviceTokenClient.dioFor()),
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
