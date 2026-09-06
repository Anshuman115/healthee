/// An acknowledged write: duplicate-tap protection, and a refusal that is shown.
///
/// The behaviour is unchanged by the v02 redesign and is the point of the widget
/// — a write that failed says so, in the server's own words, beside the control
/// that attempted it (Standards §1 forbids a swallowed failure). What changed is
/// the chrome: it draws the prototype's `.button.secondary` instead of a Material
/// `OutlinedButton`, so a screen rebuilt to v02 does not grow one control from a
/// different design.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/api/problem_message.dart';
import 'package:healthee/shared/v02/controls.dart';

/// A button that performs one server write and reports what happened.
class ServerActionButton extends StatefulWidget {
  /// [onSaved] runs only after the server acknowledged.
  const ServerActionButton({
    required this.label,
    required this.action,
    required this.onSaved,
    this.full = true,
    super.key,
  });

  /// What the control says.
  final String label;

  /// The write.
  final Future<void> Function() action;

  /// Re-reads whatever the write changed.
  final VoidCallback onSaved;

  /// `.button.full`. False for a control sharing a `.two` row.
  final bool full;

  @override
  State<ServerActionButton> createState() => _ServerActionButtonState();
}

class _ServerActionButtonState extends State<ServerActionButton> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ActionButton(
          label: _busy ? 'Working…' : widget.label,
          onPressed: _busy ? null : _run,
          secondary: true,
          full: widget.full,
        ),
        if (_error case final String message)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: TypeScale.tinyLabel.copyWith(color: colors.ink2),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.action();
      if (mounted) {
        widget.onSaved();
      }
    } on Exception catch (error, stack) {
      AppLog.failure('action', 'performing server action', error, stack);
      if (mounted) {
        setState(() => _error = apiProblem(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
