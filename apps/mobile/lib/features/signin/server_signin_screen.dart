/// Account & server — `H.screens.account`, carrying the real sign-in.
///
/// ```js
/// H.screens.account = () => `${H.header('Your data. Your space.','Account & server',true)}
///   <div class="card"><div class="row">${H.icon('shield')}<h3>A private connection</h3></div>
///     <p class="small section">…</p></div>
///   <form id="server-form" class="section"><label class="field">Server address…</label>
///     <button class="button secondary full">Test sample connection</button></form>
///   <div class="card flush section">${two rows}</div>
///   ${H.footer()}`;
/// ```
///
/// ## One surface, not two
///
/// The prototype has an `account` screen with an address field and a separate
/// `welcome` screen that links to it. This product already had a real sign-in
/// screen at `/server`, reached from Settings and from Today's data-health
/// section. Building the prototype's account screen as a *second* place to type
/// a server address would be two doors onto one keystore write — the shape
/// `server_setting.dart` was deleted for. So this screen **is** the account
/// screen, and the settings row points at it.
///
/// ## This screen is a destination, never a gate
///
/// Nothing redirects here. **Strap-only is a supported mode**: the whole
/// measured half of Today comes off this phone's own store and renders with no
/// network at all, and a sign-in wall in front of it would take the owner's own
/// measurements away until they satisfied a server.
///
/// ## The address is shown; the token is not, ever
///
/// `server_session_card.dart` argues it: a stored secret with no consumer must
/// not acquire one just so it can be rendered into a screenshot and an
/// accessibility tree. `test/signin/signin_secrecy_test.dart` executes the
/// claim rather than trusting this comment.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/features/signin/server_signin_controller.dart';
import 'package:healthee/features/signin/widgets/server_session_card.dart';
import 'package:healthee/features/signin/widgets/server_signin_form.dart';
import 'package:healthee/features/signin/widgets/signin_failure_card.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/list_row.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';

/// Sign in to the Healthee server, or review the session already held.
class ServerSignInScreen extends ConsumerWidget {
  /// [onDone] is the route back into the app. Null in tests.
  const ServerSignInScreen({this.onDone, super.key});

  /// The prototype's own h1.
  static const String title = 'Your data. Your space.';

  /// Its eyebrow.
  static const String eyebrow = 'Account & server';

  /// The prototype's own promise, made true: this app contacts the server the
  /// owner named and nothing else.
  static const String privacy =
      'Your health history belongs on the server you choose. Healthee talks to '
      'that address and to your strap, and to nothing else.';

  /// `.card .row { gap: 12px }` and `.section { margin-top: 24px }`.
  static const double rowGap = 12;

  /// Called after a sign-in lands.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return SettingsPage(
      title: title,
      eyebrow: eyebrow,
      children: <Widget>[
        PlainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.shield_outlined, color: colors.accent),
                  const SizedBox(width: rowGap),
                  Expanded(
                    child: Text(
                      'A private connection',
                      style: FormType.heading3.copyWith(color: colors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SectionGap.height),
              const SmallProse(privacy),
            ],
          ),
        ),
        const SectionGap(),
        AsyncView<ServerSessionStatus>(
          value: ref.watch(serverSessionProvider),
          onRetry: () => ref.invalidate(serverSessionProvider),
          loadingLabel: 'Checking what is already signed in',
          errorMessage: "Couldn't read this phone's keystore",
          builder: (context, session) =>
              _SignInBody(session: session, onDone: onDone),
        ),
        const SectionGap(),
        FlushCard(
          children: <Widget>[
            ListRow(
              icon: Icons.person_outline,
              title: 'How this app signs in',
              subtitle: 'Welcome and account connection',
              onTap: () => unawaited(context.push(Routes.welcome)),
            ),
            ListRow(
              icon: Icons.shield_outlined,
              title: 'Your data & privacy',
              subtitle: 'What stays local and what is uploaded',
              onTap: () => unawaited(context.push(Routes.about)),
            ),
          ],
        ),
        const DataFooter(),
      ],
    );
  }
}

class _SignInBody extends ConsumerStatefulWidget {
  const _SignInBody({required this.session, required this.onDone});

  final ServerSessionStatus session;
  final VoidCallback? onDone;

  @override
  ConsumerState<_SignInBody> createState() => _SignInBodyState();
}

class _SignInBodyState extends ConsumerState<_SignInBody> {
  /// True once the owner has asked to point at a different server, so the form
  /// replaces the summary without the session having been cleared first.
  bool _replacing = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serverSignInControllerProvider);
    final controller = ref.read(serverSignInControllerProvider.notifier);
    final session = widget.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (session.signedIn && !_replacing)
          ServerSessionCard(
            baseUrl: session.baseUrl!,
            enabled: !state.isBusy,
            onSignOut: () => unawaited(controller.signOut()),
            onReplace: () => setState(() => _replacing = true),
          )
        else
          ServerSignInForm(
            // The stored server when there is one, so "use a different server"
            // starts from what is actually in use rather than from the build's
            // compiled-in default.
            initialUrl: session.baseUrl ?? Env.apiBaseUrl,
            enabled: !state.isBusy,
            onEdited: controller.clearFailure,
            onSubmit: (url, token) => unawaited(_submit(url: url, token: token)),
          ),
        if (state.failure case final failure?) ...<Widget>[
          const SectionGap(),
          SignInFailureCard(failure: failure, onRetry: controller.clearFailure),
        ],
        if (state.isBusy) ...<Widget>[
          const SectionGap(),
          LoadingState(label: state.busyLabel),
        ],
      ],
    );
  }

  /// Runs the check and leaves only if it landed.
  ///
  /// The `mounted` guard is not ceremony: the check is a network round trip and
  /// this screen can be popped while it is in flight.
  Future<void> _submit({required String url, required String token}) async {
    final controller = ref.read(serverSignInControllerProvider.notifier);
    final signedIn = await controller.signIn(url: url, token: token);
    if (!signedIn || !mounted) {
      return;
    }
    setState(() => _replacing = false);
    widget.onDone?.call();
  }
}
