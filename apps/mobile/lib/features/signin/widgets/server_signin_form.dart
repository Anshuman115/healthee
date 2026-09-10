/// The server address, an email and a password — the sign-in this app is for.
///
/// ## What the form says, in the form
///
/// The same discipline `zepp_sign_in_form.dart` uses: the promise about where a
/// secret goes is on screen next to the field that collects it, because that is
/// where the question gets asked. Here there are two promises and they are
/// different, so both are made: the password goes to the identity provider and
/// never to the Healthee server, and the credential this phone ends up holding
/// is one the server minted for this phone alone.
///
/// ## Why the address is still a field
///
/// This product is self-hostable, and the owner's server is wherever they put
/// it. The identity provider is fixed at build time (`core/env.dart`) and the
/// server is not, so the address stays and the provider does not appear.
///
/// ## The reveal toggle
///
/// Obscured by default, with an eye. Being able to look at what is in the field
/// is a correctness feature rather than a convenience — a mistyped password and
/// a wrong password are the same 400 from the provider, and only one of them is
/// worth resetting an account over.
///
/// **The password is never rendered anywhere but this field.** Not in the
/// semantics label, not in a log line, and not in the state object — see
/// `server_signin_state.dart`, and `test/signin/signin_secrecy_test.dart`,
/// which executes the claim.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/fields.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

/// Collects the server address and the API token.
class ServerSignInForm extends StatefulWidget {
  /// [initialUrl] prefills the address; [onSubmit] receives the three fields as
  /// typed. [onUseToken] opens the transitional pasted-token path, or is null
  /// where that path should not be offered.
  const ServerSignInForm({
    required this.initialUrl,
    required this.onSubmit,
    this.onUseToken,
    required this.onEdited,
    required this.enabled,
    super.key,
  });

  /// What the address field starts with — the stored server, or the build's.
  final String initialUrl;

  /// Runs the check. Trimming is the data layer's job, in one place.
  final void Function(String url, String email, String password) onSubmit;

  /// Opens the ⛔ transitional token form. Null hides the way in entirely.
  final VoidCallback? onUseToken;

  /// Called on the first edit after a failure, so stale copy can be cleared.
  final VoidCallback onEdited;

  /// False while a check is in flight.
  final bool enabled;

  @override
  State<ServerSignInForm> createState() => _ServerSignInFormState();
}

class _ServerSignInFormState extends State<ServerSignInForm> {
  late final TextEditingController _url = TextEditingController(
    text: widget.initialUrl,
  );
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _revealed = false;

  @override
  void dispose() {
    // A controller holding a password is memory we can drop early, and must
    // drop at all: leaking it would keep the string alive for the life of the
    // isolate. Cleared before disposal, so the characters go with the widget.
    _password
      ..clear()
      ..dispose();
    _email.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (_url.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      return;
    }
    widget.onSubmit(_url.text, _email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Sign in to your server',
            style: FormType.heading3.copyWith(color: colors.ink),
          ),
          const SizedBox(height: SectionGap.height),
          const SmallProse(
            'Healthee reads what your strap measured with no server at all. '
            'Signing in adds the half that is worked out on it — recovery, '
            'sleep health, debt, VO₂max and biological age — and it is what '
            'keeps your readings yours: every request after this carries who '
            'you are, and the server answers with your rows and nobody else’s.',
          ),
          const SizedBox(height: SectionGap.height),
          HField(
            label: 'Server address',
            hint: 'https:// unless it is this phone itself',
            child: HTextField(
              controller: _url,
              enabled: widget.enabled,
              keyboardType: TextInputType.url,
              onChanged: (_) => widget.onEdited(),
            ),
          ),
          HField(
            label: 'Email',
            hint: 'The account you sign in to Healthee with',
            child: HTextField(
              controller: _email,
              enabled: widget.enabled,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => widget.onEdited(),
            ),
          ),
          HField(
            label: 'Password',
            hint: 'Checked by your identity provider, never by this app',
            child: HTextField(
              controller: _password,
              enabled: widget.enabled,
              obscure: !_revealed,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => widget.onEdited(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _revealed = !_revealed),
                tooltip: _revealed ? 'Hide the password' : 'Show the password',
                icon: Icon(
                  _revealed
                      ? SolarIconsOutline.eyeClosed
                      : SolarIconsOutline.eye,
                  size: 18,
                  color: colors.ink3,
                ),
              ),
            ),
          ),
          const SmallProse(
            'Your password goes to the identity provider and never to the '
            'Healthee server. What this phone keeps afterwards is a key the '
            'server made for this phone alone — held in the secure keystore, '
            'sent only to the address above, never written to a log, and '
            'revocable from your account if you lose the device.',
          ),
          const SizedBox(height: SectionGap.height),
          HButton(
            label: 'Sign in',
            onPressed: widget.enabled ? _submit : null,
          ),
          if (widget.onUseToken case final VoidCallback open) ...<Widget>[
            const SizedBox(height: SectionGap.height),
            HLinkButton(
              label: 'Sign in with an API token instead',
              onPressed: widget.enabled ? open : null,
            ),
          ],
        ],
      ),
    );
  }
}
