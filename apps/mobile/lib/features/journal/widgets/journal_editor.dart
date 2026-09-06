import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/journal/journal_repository.dart';
import 'package:healthee/data/journal/log_draft.dart';
import 'package:healthee/data/journal/log_kind.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/journal/widgets/journal_recent.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Form state is discarded when its owning repository/account changes.
class JournalEditor extends ConsumerStatefulWidget {
  const JournalEditor({required this.repository, super.key});
  final JournalRepository repository;

  @override
  ConsumerState<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends ConsumerState<JournalEditor> {
  final _value = TextEditingController();
  final _notes = TextEditingController();
  LogKind _kind = LogKind.caffeine;
  DateTime? _at;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      const Text(
        'Record what your strap cannot measure. These observations add context to your readings.',
      ),
      StateCard(child: Column(children: _fields(context))),
      if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
      JournalRecent(
        busy: _busy,
        onFast: ({required end}) =>
            _submit(() => widget.repository.fasting(end: end)),
      ),
    ];
    return ListView.separated(
      itemCount: sections.length,
      separatorBuilder: (context, index) => const SizedBox(height: Insets.lg),
      itemBuilder: (context, index) => sections[index],
    );
  }

  List<Widget> _fields(BuildContext context) => [
    _kindPicker(),
    TextField(
      controller: _value,
      enabled: !_busy,
      keyboardType: _kind.needsName
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: _kind.needsName ? 'Description' : 'Amount',
        suffixText: _kind.unit,
      ),
    ),
    TextField(
      controller: _notes,
      enabled: !_busy,
      maxLength: 2000,
      decoration: const InputDecoration(labelText: 'Notes (optional)'),
    ),
    TextButton(
      onPressed: _busy ? null : _pickTime,
      child: Text(_at == null ? 'When: now' : 'When: ${_at!.toLocal()}'),
    ),
    if (_kind.isDuration)
      const Text('The selected time is when the session ended.'),
    FilledButton(
      onPressed: _busy ? null : _save,
      child: Text(_busy ? 'Saving…' : 'Save entry'),
    ),
  ];

  Widget _kindPicker() => DropdownButton<LogKind>(
    value: _kind,
    isExpanded: true,
    items: [
      for (final kind in LogKind.values)
        DropdownMenuItem(value: kind, child: Text(kind.label)),
    ],
    onChanged: _busy
        ? null
        : (kind) => setState(() {
            _kind = kind!;
            _value.clear();
            _message = null;
          }),
  );

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _at ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at ?? now),
    );
    if (time == null || !mounted) return;
    setState(
      () =>
          _at = DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  Future<void> _save() async {
    final draft = LogDraft(
      kind: _kind,
      at: _at ?? DateTime.now(),
      amount: _kind.needsName ? null : double.tryParse(_value.text.trim()),
      name: _kind.needsName ? _value.text : null,
      notes: _notes.text,
    );
    final problem = draft.validate(DateTime.now());
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    await _submit(() => widget.repository.save(draft), clearForm: true);
  }

  Future<void> _submit(
    Future<String?> Function() operation, {
    bool clearForm = false,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final notice = await operation();
      if (!mounted) return;
      ref.invalidate(journalFeedProvider);
      ref.invalidate(todaySnapshotProvider);
      setState(() {
        _message = notice ?? 'Saved.';
        if (clearForm) {
          _value.clear();
          _notes.clear();
          _at = null;
        }
      });
    } on Exception catch (error, stack) {
      AppLog.failure('journal', 'saving an observation', error, stack);
      if (mounted) {
        setState(
          () => _message =
              'Save could not be confirmed. Refresh recent entries before retrying. Your form is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
