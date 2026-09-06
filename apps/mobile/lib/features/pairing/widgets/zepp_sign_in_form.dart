/// The Zepp email and password form — the happy path's first and only typing.
///
/// The strap's MAC and pairing key are already on the owner's Zepp account,
/// because pairing it in Zepp's own app is what put them there. Reading them
/// from the account is how Gadgetbridge users have always done this, and it is
/// why nobody here has to find a hex string in a settings screen.
///
/// ## What this form promises, in the form
///
/// The password goes to `zepp.com` and nowhere else — not to the Healthee
/// server, which has no endpoint for it. That sentence is on screen rather than
/// in a privacy page, because it is the question a reasonable person asks when
/// an app they self-host wants a third-party password, and the answer is good.
///
/// v02's `.field` geometry; the promises, the opt-in default and the disposal
/// are unchanged. **Remembering is off by default** — storing somebody's
/// password is a thing they opt into, not out of — and the switch is the
/// prototype's own `.toggle-row`, which states what turning it on adds.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/fields.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:healthee/shared/v02/toggle_row.dart';

/// Collects a Zepp sign-in and the "remember this" opt-in.
class ZeppSignInForm extends StatefulWidget {
  /// [onSubmit] receives a trimmed email and the password as typed.
  const ZeppSignInForm({
    required this.onSubmit,
    required this.onRememberChanged,
    required this.onUseManualEntry,
    required this.rememberZepp,
    required this.enabled,
    super.key,
  });

  /// Runs the sign-in.
  final void Function(String email, String password) onSubmit;

  /// Records the opt-in.
  final ValueChanged<bool> onRememberChanged;

  /// Switches to the manual fallback.
  final VoidCallback onUseManualEntry;

  /// Current value of the opt-in.
  final bool rememberZepp;

  /// False while a sign-in is in flight.
  final bool enabled;

  @override
  State<ZeppSignInForm> createState() => _ZeppSignInFormState();
}

class _ZeppSignInFormState extends State<ZeppSignInForm> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    // A TextEditingController holding a password is memory we can drop early,
    // and must drop at all: leaking it would keep the string alive for the life
    // of the isolate.
    _password
      ..clear()
      ..dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      return;
    }
    widget.onSubmit(email, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PlainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Sign in to Zepp',
                style: FormType.heading3.copyWith(color: colors.ink),
              ),
              const SizedBox(height: SectionGap.height),
              const SmallProse(
                'Your strap is already bound to a Zepp account, and its '
                'pairing key is stored there. Signing in reads it out. The '
                'password goes to zepp.com and nowhere else — the Healthee '
                'server never sees it and has no endpoint that could.',
              ),
              const SizedBox(height: SectionGap.height),
              HField(
                label: 'Zepp email',
                child: HTextField(
                  controller: _email,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              HField(
                label: 'Zepp password',
                child: HTextField(
                  controller: _password,
                  enabled: widget.enabled,
                  obscure: true,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              HButton(
                label: 'Find my straps',
                onPressed: widget.enabled ? _submit : null,
              ),
            ],
          ),
        ),
        const SectionGap(),
        FlushCard(
          children: <Widget>[
            ToggleRow(
              title: 'Remember this Zepp sign-in',
              body: PairingDisclosure.whatRememberingAdds,
              value: widget.rememberZepp,
              onChanged: widget.enabled ? widget.onRememberChanged : null,
            ),
          ],
        ),
        const SectionGap(),
        HButton(
          label: 'Enter the MAC and key by hand instead',
          kind: HButtonKind.secondary,
          onPressed: widget.enabled ? widget.onUseManualEntry : null,
        ),
      ],
    );
  }
}
