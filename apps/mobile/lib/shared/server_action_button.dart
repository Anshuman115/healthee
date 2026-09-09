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
    this.busyNote,
    required this.action,
    required this.onSaved,
    this.style = ActionButtonStyle.legacy,
    this.full = false,
    super.key,
  });

  /// What the button says when idle.
  final String label;

  /// What the wait is for, shown under the button while the action runs.
  ///
  /// **These actions are LLM calls and they take about ten seconds.** The only
  /// feedback was the label changing to `Working…`, which on a screen that
  /// otherwise responds instantly reads as a button that did nothing — the
  /// owner's words were *"suggest a challenge and suggest a program does not
  /// work"*, and it did work, every time. A moving bar says the wait is alive
  /// and this sentence says what is being waited on.
  final String? busyNote;

  /// The write.
  /// Runs the action. A non-null string is **an outcome worth saying**: the
  /// call succeeded and produced nothing, and this is why. Null means it did
  /// what it said. Failures throw and land in [_error] instead.
  final Future<String?> Function() action;

  /// Called after [action] completes without throwing.
  final VoidCallback onSaved;

  /// Which drawing. See the library docstring.
  final ActionButtonStyle style;

  /// `.button.full` — stretches to the row. Ignored by [ActionButtonStyle.legacy],
  /// which is left-aligned by its own design.
  final bool full;

  @override
  State<ServerActionButton> createState() => _ServerActionButtonState();
}

class _ServerActionButtonState extends State<ServerActionButton> {
  /// The waiting bar.
  static const double busyTrackHeight = 3;
  static const double busyTrackRadius = 2;

  bool _busy = false;
  String? _error;

  /// Set when the run SUCCEEDED and produced nothing.
  ///
  /// **Distinct from [_error] on purpose.** A refusal by the engine's own
  /// evidence gates is not a failure — the request worked, the model's proposal
  /// did not clear the rules, and the server says which rule in words. Drawn in
  /// ordinary ink rather than the danger colour, because nothing is wrong.
  String? _outcome;

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
        ActionButtonStyle.v02 => widget.full
            ? HButton(
                label: _busy ? 'Working…' : widget.label,
                onPressed: _busy ? null : _run,
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: HButton(
                  label: _busy ? 'Working…' : widget.label,
                  onPressed: _busy ? null : _run,
                ),
              ),
      },
      if (_busy) ...<Widget>[
        const SizedBox(height: Insets.sm),
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(busyTrackRadius),
                child: LinearProgressIndicator(
                  minHeight: busyTrackHeight,
                  // Indeterminate on purpose: the server does not report
                  // progress, and a bar that filled at a rate we invented
                  // would be a claim about how long this takes.
                  backgroundColor: context.colors.line,
                  color: context.colors.accent,
                ),
              ),
              if (widget.busyNote case final String note) ...<Widget>[
                const SizedBox(height: Insets.xs),
                Text(
                  note,
                  style: FormType.small.copyWith(color: context.colors.ink2),
                ),
              ],
            ],
          ),
        ),
      ],
      if (_outcome case final String message) ...[
        const SizedBox(height: Insets.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: FormType.small.copyWith(color: context.colors.ink2),
          ),
        ),
      ],
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
      _outcome = null;
    });
    try {
      final nothing = await widget.action();
      if (mounted) {
        setState(() => _outcome = nothing);
        widget.onSaved();
      }
    } on Exception catch (error, stack) {
      AppLog.failure('action', 'performing server action', error, stack);
      if (mounted) setState(() => _error = apiProblem(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
