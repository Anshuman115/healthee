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
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

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
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign in to Zepp', style: text.titleMedium),
          const SizedBox(height: Insets.sm),
          Text(
            'Your strap is already bound to a Zepp account, and its pairing key '
            'is stored there. Signing in reads it out. The password goes to '
            'zepp.com and nowhere else — the Healthee server never sees it and '
            'has no endpoint that could.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _email,
            enabled: widget.enabled,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Zepp email'),
          ),
          const SizedBox(height: Insets.md),
          TextField(
            controller: _password,
            enabled: widget.enabled,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Zepp password'),
          ),
          const SizedBox(height: Insets.md),
          // A bare Checkbox in a Row rather than CheckboxListTile: ListTile
          // paints its background on the nearest Material ancestor and asserts
          // when it finds a DecoratedBox in between — which every StateCard is.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: widget.rememberZepp,
                onChanged: widget.enabled
                    ? (value) => widget.onRememberChanged(value ?? false)
                    : null,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Insets.md),
                    Text('Remember this Zepp sign-in', style: text.bodyMedium),
                    const SizedBox(height: Insets.xs),
                    Text(
                      PairingDisclosure.whatRememberingAdds,
                      style: text.bodySmall?.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          FilledButton(
            onPressed: widget.enabled ? _submit : null,
            child: const Text('Find my straps'),
          ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: widget.enabled ? widget.onUseManualEntry : null,
            child: const Text('Enter the MAC and key by hand instead'),
          ),
        ],
      ),
    );
  }
}
