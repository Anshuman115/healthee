/// The fallback: type the MAC and the key.
///
/// Secondary, and permanently available. The account route fails for reasons
/// that are nobody's fault and that no amount of retrying fixes — an account
/// signed in with Google rather than a password, a region whose endpoint differs
/// from the `us2` one this app speaks, a Zepp API change. Without this form each
/// of those is a dead end; with it they are a detour.
///
/// The values come from the same places they always have: `huami-token` on a
/// desktop, Gadgetbridge's device info, or an earlier install of this app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Collects a hand-typed pairing.
class ManualEntryForm extends StatefulWidget {
  /// [onSubmit] gets the raw text; validation belongs to `PairedStrap.parse`
  /// so that a typed pairing is held to the same shape as an account one.
  const ManualEntryForm({
    required this.onSubmit,
    required this.onUseAccount,
    required this.enabled,
    super.key,
  });

  /// Submits the pair for validation.
  final void Function(String mac, String authKey) onSubmit;

  /// Back to the Zepp form.
  final VoidCallback onUseAccount;

  /// False while work is in flight.
  final bool enabled;

  @override
  State<ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm> {
  final TextEditingController _mac = TextEditingController();
  final TextEditingController _key = TextEditingController();

  @override
  void dispose() {
    _key
      ..clear()
      ..dispose();
    _mac.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmit(_mac.text, _key.text);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter the pairing by hand', style: text.titleMedium),
          const SizedBox(height: Insets.sm),
          Text(
            'For when the Zepp route cannot work — a sign-in through Google, an '
            'account outside the US region, or an API that has moved. Both '
            'values also come out of huami-token or Gadgetbridge.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _mac,
            enabled: widget.enabled,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F:-]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Bluetooth MAC',
              hintText: 'DB:98:1F:80:4C:3D',
            ),
          ),
          const SizedBox(height: Insets.md),
          TextField(
            controller: _key,
            enabled: widget.enabled,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-FxX]')),
            ],
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Auth key',
              hintText: '32 hex digits, 0x optional',
            ),
          ),
          const SizedBox(height: Insets.lg),
          FilledButton(
            onPressed: widget.enabled ? _submit : null,
            child: const Text('Use this pairing'),
          ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: widget.enabled ? widget.onUseAccount : null,
            child: const Text('Back to signing in with Zepp'),
          ),
        ],
      ),
    );
  }
}
