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
import 'package:healthee/data/auth/identity_client.dart';
import 'package:healthee/data/auth/identity_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'identity_providers.g.dart';

/// The app's identity client, or null on a build with no provider configured.
@Riverpod(keepAlive: true)
IdentityClient? identityClient(Ref ref) {
  if (!Env.hasIdentityProvider) {
    return null;
  }
  final secrets = ref.watch(secretStoreProvider);
  final client = IdentityClient(
    GoTrueClient(
      // gotrue's own path under a Supabase project. The client is given the
      // auth endpoint, not the project root, because nothing else on that
      // project is ever called from this app.
      url: '${Env.supabaseUrl}/auth/v1',
      headers: <String, String>{'apikey': Env.supabaseAnonKey},
      // The refresh timer is the whole reason a screen can ask for a token and
      // get a live one. Off, every `/api/*` call an hour after sign-in is a 401.
      autoRefreshToken: true,
      // Email and password, so there is no browser round trip to come back from
      // and no deep link to register. PKCE is for the OAuth flows this app does
      // not offer, and choosing it would mean carrying `app_links` for nothing.
      flowType: AuthFlowType.implicit,
      asyncStorage: KeystoreIdentityStore(secrets),
    ),
    secrets,
  );
  ref.onDispose(() => client.dispose());
  return client;
}


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
