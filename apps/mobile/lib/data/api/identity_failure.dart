/// Every way signing in to the IDENTITY provider can fail, named.
///
/// The sibling of `data/api/signin_failure.dart`, which names the ways the
/// SERVER can refuse — and the same rule applies, for the same reason: *"something
/// went wrong" is banned in this product.* A failure with no way forward is the
/// interface equivalent of a swallowed exception.
///
/// The distinction those two files draw between them is the one that costs an
/// evening when it is wrong:
///
/// ```text
///   Supabase refused the credentials     → IdentityRefused        (change the password)
///   Supabase has no account for them     → IdentityNeedsSignUp    (create one)
///   Supabase accepted, mail not opened   → IdentityNeedsConfirmation
///   Supabase never answered              → IdentityUnreachable    (check the network)
///   Supabase accepted, OUR server said no→ SignupNotInvited       (ask the operator)
/// ```
///
/// The last one is the one that has to be its own case. An owner who typed a
/// correct password and got "sign-in failed" would go and reset a password that
/// was never the problem — the account is real, the credentials were right, and
/// this deployment simply is not open to them.
///
/// ## Nothing here carries a token, a password or a provider message
///
/// `AuthException.message` is Supabase's own string about an HTTP response, and
/// it can quote a body. Only its `code` — a short, stable, secret-free
/// identifier — is used, and only to CHOOSE which of these cases to raise.
/// It is a `part` of `signin_failure.dart` rather than its own library because
/// [ServerSignInFailure] is **sealed** — one closed set of ways a sign-in can
/// fail, so a screen rendering them cannot miss one. Sealed types cannot be
/// extended across libraries, and splitting the file was the alternative to
/// giving that up for the 400-line gate. The `gotrue` mapping lives in
/// `data/auth/identity_failure_mapping.dart`, so this file — like the one it is
/// part of — imports no identity provider at all.
part of 'signin_failure.dart';

/// The identity provider read the credentials and refused them.
///
/// ## It cannot tell you WHICH, and neither can this app
///
/// Supabase answers `invalid_credentials` both for a wrong password and for an
/// email it has never seen, deliberately: an error that distinguished them would
/// be a way to ask "does this person have an account here?" about anybody, one
/// address at a time. That is a real protection and this app must not try to
/// route around it — there is no client-side way to check, because listing users
/// needs the service-role key and that key must never ship in a client.
///
/// So the remedy names BOTH possibilities. An earlier version said only "check
/// them and try again", which is advice for one of the two cases and a dead end
/// for the other — the owner who has no account yet retypes a correct password
/// until they give up, with a "Create an account" link on the same screen they
/// have no reason to look at.
@immutable
final class IdentityRefused extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityRefused();

  @override
  String get headline => 'That email and password did not match';

  @override
  String get remedy =>
      'Either the password is wrong, or there is no account for that email yet '
      '— the sign-in service will not say which. If you have not made one, use '
      '“Create an account” below. If you have, and you have forgotten the '
      'password, reset it with your identity provider; this app cannot.';

  @override
  String get code => 'identity_refused';

  /// Retrying the same pair fails identically.
  @override
  bool get canRetry => false;
}

/// There is no account for that email yet.
@immutable
final class IdentityNeedsSignUp extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityNeedsSignUp();

  @override
  String get headline => 'No account for that email';

  @override
  String get remedy => 'Create one, or check the address for a typo.';

  @override
  String get code => 'identity_no_account';

  @override
  bool get canRetry => false;
}

/// The account exists and its email has not been confirmed.
@immutable
final class IdentityNeedsConfirmation extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityNeedsConfirmation();

  @override
  String get headline => 'Confirm your email first';

  @override
  String get remedy =>
      'We have sent you a link. Open it, then come back and sign in — your '
      'account exists and nothing has gone wrong.';

  @override
  String get code => 'identity_unconfirmed';

  @override
  bool get canRetry => false;
}

/// That email already has an account.
@immutable
final class IdentityAlreadyExists extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityAlreadyExists();

  @override
  String get headline => 'That email already has an account';

  @override
  String get remedy => 'Sign in instead of creating a new one.';

  @override
  String get code => 'identity_exists';

  @override
  bool get canRetry => false;
}

/// The password is shorter or simpler than the provider will accept.
@immutable
final class IdentityWeakPassword extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityWeakPassword();

  @override
  String get headline => 'That password is too weak';

  @override
  String get remedy => 'Use a longer one. Your identity provider sets the rule.';

  @override
  String get code => 'identity_weak_password';

  @override
  bool get canRetry => false;
}

/// Sign-ups are switched off at the identity provider itself.
@immutable
final class IdentitySignUpDisabled extends ServerSignInFailure {
  /// Builds the failure.
  const IdentitySignUpDisabled();

  @override
  String get headline => 'This identity provider is not taking new accounts';

  @override
  String get remedy =>
      'Ask whoever runs this server to invite you. Nothing is wrong with what '
      'you typed.';

  @override
  String get code => 'identity_signup_disabled';

  @override
  bool get canRetry => false;
}

/// Too many attempts, too quickly.
@immutable
final class IdentityRateLimited extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityRateLimited();

  @override
  String get headline => 'Too many attempts';

  @override
  String get remedy => 'Wait a minute and try again.';

  @override
  String get code => 'identity_rate_limited';
}

/// The request never reached the identity provider.
@immutable
final class IdentityUnreachable extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityUnreachable();

  @override
  String get headline => "Couldn't reach the sign-in service";

  @override
  String get remedy =>
      'Check the connection and try again. Your password was never sent, so '
      'nothing about your account has changed.';

  @override
  String get code => 'identity_unreachable';
}

/// This build was given no identity provider to sign in against.
@immutable
final class IdentityNotConfigured extends ServerSignInFailure {
  /// Builds the failure.
  const IdentityNotConfigured();

  @override
  String get headline => 'This build has no sign-in';

  @override
  String get remedy =>
      'It was built without a Supabase project, so there is nothing to sign in '
      'to. The strap still pairs and every screen still reads from this phone.';

  @override
  String get code => 'identity_not_configured';

  @override
  bool get canRetry => false;
}

/// The identity provider said yes and **this server** said no.
///
/// Two states reach here and they share a remedy: a new owner this deployment
/// has not invited (`SIGNUP_ALLOWLIST`), and an existing owner whose account has
/// been suspended. Both are 403 — the server knows exactly who you are and will
/// not serve you — and in both the person to ask is whoever runs the server.
///
/// **It has to be its own case, apart from a refused credential.** An owner who
/// typed a correct password and read "sign-in failed" would go and reset a
/// password that was never the problem. The sign-in worked; the account is real;
/// this particular server is simply not open to it.
@immutable
final class ServerRefusedThisAccount extends ServerSignInFailure {
  /// Builds the failure.
  const ServerRefusedThisAccount();

  @override
  String get headline => 'This server will not open for your account';

  @override
  String get remedy =>
      'Your sign-in itself worked, so nothing is wrong with your email or '
      'password. This server is invite-only, or your account has been paused. '
      'Ask whoever runs it.';

  @override
  String get code => 'server_refused_account';

  @override
  bool get canRetry => false;
}


/// The account already holds as many device tokens as the server allows.
@immutable
final class DeviceTokenCapReached extends ServerSignInFailure {
  /// [detail] is the SERVER's own sentence, when it sent one.
  const DeviceTokenCapReached(this.detail);

  /// What the server said, verbatim. Null when it sent nothing readable.
  ///
  /// Carried rather than replaced because `apps/server` writes this refusal for
  /// a person: it names the cap, says revoking one frees a slot, and it is the
  /// side that knows what the number is. A client that composed its own sentence
  /// would be a second definition of a limit it does not own.
  final String? detail;

  @override
  String get headline => 'This account has too many devices signed in';

  @override
  String get remedy =>
      detail ??
      'Sign out on a device you no longer use, then try again. Each phone that '
      'signs in holds its own key, and there is a limit on how many can be live '
      'at once.';

  @override
  String get code => 'device_cap_reached';

  @override
  bool get canRetry => false;
}


/// The identity provider refused, and this app does not recognise the reason.
///
/// ## Why this exists rather than falling back to [IdentityRefused]
///
/// Defaulting an unknown code to "wrong credentials" is defensible on a SIGN-IN
/// and nonsense on a SIGN-UP — there is nothing to match against, so "that email
/// and password did not match" sends the owner to check a password they were in
/// the middle of choosing. That is not hypothetical: it is exactly what this app
/// said when a project with email confirmation on could not send the mail.
///
/// It carries the provider's stable error code — `weak_password`,
/// `over_email_send_rate_limit`, `error_sending_confirmation_email`. A code is
/// not a message and not a body: it is a short identifier from a documented set,
/// it names no user and quotes no input, and it is the difference between an
/// owner who can search for their problem and one who cannot. The message stays
/// out, because that is the part that can echo what was typed.
@immutable
final class IdentityUnrecognised extends ServerSignInFailure {
  /// [providerCode] is the provider's own; [creating] picks the wording.
  const IdentityUnrecognised(this.providerCode, {required this.creating});

  /// The provider's stable error code, or null when it sent none.
  final String? providerCode;

  /// Whether this was an attempt to CREATE an account rather than sign in.
  final bool creating;

  @override
  String get headline => creating
      ? 'That account could not be created'
      : 'The sign-in service refused that';

  @override
  String get remedy {
    final named = providerCode == null ? '' : ' It reported “$providerCode”.';
    return creating
        ? 'Your email and password were not the problem — the sign-in service '
              'itself would not complete the request.$named Ask whoever runs '
              'this server, or try again in a few minutes.'
        : 'Nothing here says your details were wrong; the service refused the '
              'request for another reason.$named Try again in a few minutes.';
  }

  @override
  String get code => 'identity_unrecognised';
}
