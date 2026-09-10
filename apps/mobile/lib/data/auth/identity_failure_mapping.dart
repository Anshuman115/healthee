/// `gotrue`'s exceptions, mapped onto this app's named sign-in failures.
///
/// Its own file so `data/api/identity_failure.dart` — which is a `part` of
/// `signin_failure.dart` — imports no identity provider. The failure taxonomy is
/// about what an owner should DO next; which library produced the error is an
/// implementation detail of one screen's plumbing, and the two should not have
/// to change together.
library;

import 'package:gotrue/gotrue.dart';
import 'package:healthee/data/api/signin_failure.dart';

/// Maps a `gotrue` exception onto one of this app's named failures.
///
/// The CODE, never the message: the message is the provider's own prose about
/// an HTTP response and it can quote a body.
///
/// ## An unrecognised code is not "wrong credentials"
///
/// It used to fall to [IdentityRefused], on the reasoning that the request
/// landed and the likely answer is a bad password. That reasoning holds for a
/// sign-in and collapses for a sign-up: there is nothing to match against, so
/// "that email and password did not match" tells someone choosing a new password
/// that the one they just invented is wrong. It shipped, and it cost a round
/// trip to work out that the real answer was a project that could not send its
/// confirmation email.
///
/// [creating] is therefore required rather than defaulted — a caller has to say
/// which operation failed, because the honest wording differs.
ServerSignInFailure identityFailure(
  AuthException error, {
  required bool creating,
}) =>
    switch (error.code) {
      // The real code for a refused password — and for an email the provider
      // has never seen, which it deliberately will not distinguish.
      'invalid_credentials' ||
      'invalid_grant' => const IdentityRefused(),
      'email_not_confirmed' => const IdentityNeedsConfirmation(),
      'user_not_found' => const IdentityNeedsSignUp(),
      'email_exists' || 'user_already_exists' => const IdentityAlreadyExists(),
      'weak_password' => const IdentityWeakPassword(),
      'signup_disabled' || 'email_provider_disabled' =>
        const IdentitySignUpDisabled(),
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        const IdentityRateLimited(),
      // The provider answered and named a reason this app has no case for.
      // Said plainly, with the code, rather than guessed at.
      final String unknown => IdentityUnrecognised(unknown, creating: creating),
      _ => creating
          ? const IdentityUnrecognised(null, creating: true)
          : const IdentityRefused(),
    };
