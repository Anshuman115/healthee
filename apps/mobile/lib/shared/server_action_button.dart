import 'package:flutter/material.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/problem_message.dart';

/// Acknowledged writes with duplicate-tap protection and visible refusals.
class ServerActionButton extends StatefulWidget {
  const ServerActionButton({
    required this.label,
    required this.action,
    required this.onSaved,
    super.key,
  });
  final String label;
  final Future<void> Function() action;
  final VoidCallback onSaved;

  @override
  State<ServerActionButton> createState() => _ServerActionButtonState();
}

class _ServerActionButtonState extends State<ServerActionButton> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton(
        onPressed: _busy ? null : _run,
        child: Text(_busy ? 'Working…' : widget.label),
      ),
      if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
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
