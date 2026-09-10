/// The app's one [IdentityClient], and the `gotrue` client under it.
///
/// `keepAlive` because a signed-in session is process-wide state, not a screen's:
/// rebuilding the client would drop the in-memory session and the refresh timer
/// with it, and every screen would have to recover one from the keystore.
///
/// **Null when this build has no identity provider.** A self-hoster who never
/// made a Supabase project gets a null here, the sign-in screen says so plainly,
/// and everything else in the app carries on — the strap pairs, the local store
/// serves every screen, and a pasted server token still works. A provider that
/// threw here instead would take the whole app down over a missing dart-define.
library;

import 'package:gotrue/gotrue.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/secret_store.dart';
import 'package:healthee/data/auth/auth_config.dart';
import 'package:healthee/data/auth/identity_client.dart';
import 'package:healthee/data/auth/identity_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'identity_providers.g.dart';

/// The app's identity client, or null on a build with no provider configured.
@Riverpod(keepAlive: true)
IdentityClient? identityClient(Ref ref) {
  final secrets = ref.watch(secretStoreProvider);
  final credentials = ref.watch(credentialsProvider);
  // ⛔ The STORED config first, `Env` only as a fallback.
  //
  // The stored one is what the SERVER said (`GET /api/auth-config`), which is
  // what makes a published APK point at the owner's provider rather than at
  // whoever built it. The dart-defines stay as a fallback for a development build
  // aimed at a known project, and for the first run before any server has been
  // asked — but a build with neither is no longer a build that cannot sign in: it
  // is one that has not been told yet.
  final client = IdentityClient.deferred(
    resolve: () => resolveAuthConfig(credentials),
    secrets: secrets,
    build: (config) => _gotrue(config, secrets),
  );
  ref.onDispose(() => client.dispose());
  return client;
}

/// Which provider to sign in against: what the SERVER said, then the build's own.
///
/// ⛔ **The stored one wins, and that ordering is the feature.** It is what the
/// server named through `GET /api/auth-config`, which is what lets one published
/// APK point at the owner's project instead of at whoever built it. Preferring
/// the compiled-in value would quietly restore the old behaviour — the app would
/// still work, for the person who built it, and for nobody else.
///
/// The dart-defines remain as a fallback for a development build aimed at a known
/// project, and for the first run before any server has been asked. Null means
/// neither: not a broken build, just one that has not been told yet.
///
/// A named function rather than a closure so the ORDER can be tested — a mutation
/// swapping the two survived while this was inline.
Future<AuthConfig?> resolveAuthConfig(Credentials credentials) async =>
    await credentials.authConfig() ??
    (Env.hasIdentityProvider
        ? const AuthConfig(
            supabaseUrl: Env.supabaseUrl,
            anonKey: Env.supabaseAnonKey,
          )
        : null);

/// The `gotrue` client for one provider, configured the way this app needs it.
GoTrueClient _gotrue(AuthConfig config, SecretStore secrets) => GoTrueClient(
  // gotrue's own path under a Supabase project. The client is given the auth
  // endpoint, not the project root, because nothing else on that project is
  // ever called from this app.
  url: config.gotrueUrl,
  headers: <String, String>{'apikey': config.anonKey},
  // The refresh timer is the whole reason a screen can ask for a token and get
  // a live one. Off, every `/api/*` call an hour after sign-in is a 401.
  autoRefreshToken: true,
  // Email and password, so there is no browser round trip to come back from and
  // no deep link to register. PKCE is for the OAuth flows this app does not
  // offer, and choosing it would mean carrying `app_links` for nothing.
  flowType: AuthFlowType.implicit,
  asyncStorage: KeystoreIdentityStore(secrets),
);


/// Whether this build can sign in with an email and a password.
///
/// A provider rather than `Env.hasIdentityProvider` read at the call site, and
/// the difference is testability: the dart-defines behind that getter are
/// compile-time constants, so a widget test can never see a build that HAS an
/// identity provider — every sign-in test would silently exercise the
/// transitional pasted-token path and the real one would ship unproven.
///
/// Derived from [identityClientProvider] rather than from `Env` directly, so
/// there is one answer to "is there a provider" and not two that can disagree.
@Riverpod(keepAlive: true)
bool identityAvailable(Ref ref) => ref.watch(identityClientProvider) != null;
