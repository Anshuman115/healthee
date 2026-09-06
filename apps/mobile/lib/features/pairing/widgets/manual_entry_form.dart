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
///
/// v02's `.field` geometry. The input filters, the validation boundary and the
/// disposal are unchanged: `PairedStrap.parse` still owns what a valid pairing
/// is, so a typed one is held to the same shape as an account one.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/fields.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';

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
                'Enter the pairing by hand',
                style: FormType.heading3.copyWith(color: colors.ink),
              ),
              const SizedBox(height: SectionGap.height),
              const SmallProse(
                'For when the Zepp route cannot work — a sign-in through '
                'Google, an account outside the US region, or an API that has '
                'moved. Both values also come out of huami-token or '
                'Gadgetbridge.',
              ),
              const SizedBox(height: SectionGap.height),
              HField(
                label: 'Bluetooth MAC',
                child: HTextField(
                  controller: _mac,
                  enabled: widget.enabled,
                  hintText: 'DB:98:1F:80:4C:3D',
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F:-]')),
                  ],
                ),
              ),
              HField(
                label: 'Auth key',
                child: HTextField(
                  controller: _key,
                  enabled: widget.enabled,
                  hintText: '32 hex digits, 0x optional',
                  onSubmitted: (_) => _submit(),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-FxX]')),
                  ],
                ),
              ),
              HButton(
                label: 'Use this pairing',
                onPressed: widget.enabled ? _submit : null,
              ),
            ],
          ),
        ),
        const SectionGap(),
        HButton(
          label: 'Back to signing in with Zepp',
          kind: HButtonKind.secondary,
          onPressed: widget.enabled ? widget.onUseAccount : null,
        ),
      ],
    );
  }
}
