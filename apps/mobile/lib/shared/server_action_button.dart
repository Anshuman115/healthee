/// Acknowledged writes with duplicate-tap protection and visible refusals.
///
/// ## One state machine, two skins
///
/// The v02 redesign gave the settings screens the prototype's own button —
/// `.button.full`, 48 px, radius 16 — while eight other call sites sit on
/// screens that have **not** been redesigned yet. Restyling the shared control
/// would have restyled those screens by side effect, which is the failure
/// `type_scale.dart` names when it explains why v02's scale is a second file
/// rather than a remap of the Material one.
///
/// So the *behaviour* — busy latch, single flight, `AppLog.failure`, and the
/// server's own refusal rendered where the button is — stays in one place, and
/// [ActionButtonStyle] picks the presentation. That is the same shape
/// `pairing_failure_card.dart` uses: two drawings chosen by a property, never
/// two implementations.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/data/api/problem_message.dart';
import 'package:healthee/shared/v02/buttons.dart';

/// Which drawing this button wears.
enum ActionButtonStyle {
  /// The Material outlined button, on the screens not yet redesigned.
  legacy,

  /// `.button.full` — v02's own, on the redesigned settings screens.
  v02,
}

/// A write that says whether it landed.
class ServerActionButton extends StatefulWidget {
  /// Builds the button. [action] runs once per tap, never twice concurrently.
  const ServerActionButton({
    required this.label,
    required this.action,
    required this.onSaved,
    this.style = ActionButtonStyle.legacy,
    super.key,
  });

  /// What the button says when idle.
  final String label;

  /// The write.
  final Future<void> Function() action;

  /// Called after [action] completes without throwing.
  final VoidCallback onSaved;

  /// Which drawing. See the library docstring.
  final ActionButtonStyle style;

  @override
  State<ServerActionButton> createState() => _ServerActionButtonState();
}

class _ServerActionButtonState extends State<ServerActionButton> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      switch (widget.style) {
        ActionButtonStyle.legacy => Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _busy ? null : _run,
            child: Text(_busy ? 'Working…' : widget.label),
          ),
        ),
        ActionButtonStyle.v02 => HButton(
          label: _busy ? 'Working…' : widget.label,
          onPressed: _busy ? null : _run,
        ),
      },
      if (_error case final String message) ...[
        const SizedBox(height: Insets.sm),
        Semantics(
          liveRegion: true,
          child: switch (widget.style) {
            // `.form-error { color: var(--danger); font-size: 12px; }`
            ActionButtonStyle.v02 => Text(
              message,
              style: FormType.small.copyWith(color: context.colors.alert),
            ),
            ActionButtonStyle.legacy => Text(message),
          },
        ),
      ],
    ],
  );

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.action();
      if (mounted) widget.onSaved();
    } on Exception catch (error, stack) {
      AppLog.failure('action', 'performing server action', error, stack);
      if (mounted) setState(() => _error = apiProblem(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
