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

/// Maps a `gotrue` exception onto one of the cases above.
///
/// The CODE, never the message: the message is the provider's own prose about
/// an HTTP response and it can quote a body. An unrecognised code falls to
/// [IdentityRefused] rather than to a generic error, because every path that
/// reaches here got an ANSWER from the identity provider — the request landed,
/// so "check your network" would be the wrong advice — and the overwhelmingly
/// likely answer is that the credentials were not accepted.
ServerSignInFailure identityFailure(AuthException error) =>
    switch (error.code) {
      'email_not_confirmed' => const IdentityNeedsConfirmation(),
      'user_not_found' => const IdentityNeedsSignUp(),
      'email_exists' || 'user_already_exists' => const IdentityAlreadyExists(),
      'weak_password' => const IdentityWeakPassword(),
      'signup_disabled' || 'email_provider_disabled' =>
        const IdentitySignUpDisabled(),
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        const IdentityRateLimited(),
      _ => const IdentityRefused(),
    };
