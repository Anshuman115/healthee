/// Which identity provider a server expects its app to sign in against.
///
/// The app used to be COMPILED against one Supabase project, which made a
/// published APK the author's app rather than anybody's: install it and you are
/// pointed at their provider and their server. For a product whose claim is
/// self-hosting, that is backwards. So the server answers the question instead
/// (`GET /api/auth-config`), the owner types their address, and the app learns the
/// rest.
///
/// ## Four answers, because there are four situations
///
/// A server that names a provider, a server that has none, a server too old to
/// have been asked, and a server we could not reach. They need four different
/// sentences on a screen — "this server has no sign-in configured" and "your
/// connection dropped" send the owner to completely different places — so they are
/// four types rather than a nullable and a guess.
library;

import 'package:meta/meta.dart';

/// A provider a client can actually sign in against.
@immutable
class AuthConfig {
  /// Both are required: half a configuration is a form that submits into a 400.
  const AuthConfig({required this.supabaseUrl, required this.anonKey});

  /// Reads the server's body, or null when it does not name a usable provider.
  ///
  /// Null covers both the server's own "I have none" (nulls in the payload) and a
  /// body missing the fields entirely. The CALLER distinguishes those from an
  /// unreachable or too-old server, because those are facts about the request
  /// rather than about the answer.
  static AuthConfig? fromJson(Map<String, Object?> json) {
    final url = json['supabase_url'];
    final key = json['supabase_anon_key'];
    if (url is! String || url.isEmpty || key is! String || key.isEmpty) {
      return null;
    }
    return AuthConfig(supabaseUrl: url, anonKey: key);
  }

  /// Round-trips through the keystore, so a cold start needs no network.
  static AuthConfig? fromStored(Map<String, Object?> json) => fromJson(json);

  /// The Supabase project URL, e.g. `https://abcd.supabase.co`.
  final String supabaseUrl;

  /// That project's **anon** key. Published by design: it identifies the project
  /// and authorises nothing on its own, because every row policy still applies.
  final String anonKey;

  /// What `gotrue` is given — the auth endpoint, never the project root.
  String get gotrueUrl => '$supabaseUrl/auth/v1';

  /// For the keystore. The same keys the wire uses, so there is one shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'supabase_url': supabaseUrl,
    'supabase_anon_key': anonKey,
  };

  @override
  bool operator ==(Object other) =>
      other is AuthConfig &&
      other.supabaseUrl == supabaseUrl &&
      other.anonKey == anonKey;

  @override
  int get hashCode => Object.hash(supabaseUrl, anonKey);
}

/// What asking a server for its identity provider produced.
@immutable
sealed class AuthConfigResult {
  /// Const base.
  const AuthConfigResult();
}

/// The server named a provider.
@immutable
final class AuthConfigFound extends AuthConfigResult {
  /// Wraps it.
  const AuthConfigFound(this.config);

  /// The provider to sign in against.
  final AuthConfig config;
}

/// The server answered, and said it has no identity provider configured.
///
/// A real state — a box running strap-only — and the owner should be told that
/// plainly rather than shown a sign-in form that cannot work.
@immutable
final class AuthConfigNone extends AuthConfigResult {
  /// Nothing to carry.
  const AuthConfigNone();
}

/// The server has no such endpoint: it predates the question.
///
/// Distinct from [AuthConfigNone] because the remedy is different — this server
/// needs updating, that one needs configuring — and a 404 is exactly how the
/// server tells us which. `api/routers/auth.py` returns 200-with-nulls for the
/// other case precisely so these stay apart.
@immutable
final class AuthConfigUnsupported extends AuthConfigResult {
  /// Nothing to carry.
  const AuthConfigUnsupported();
}

/// We could not ask. Says nothing about the server.
@immutable
final class AuthConfigUnreachable extends AuthConfigResult {
  /// Nothing to carry.
  const AuthConfigUnreachable();
}
