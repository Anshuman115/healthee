import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/profile/health_profile.dart';
import 'package:healthee/data/profile/profile_repository.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/profile/widgets/activity_level_field.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({
    required this.repository,
    required this.profile,
    super.key,
  });
  final ProfileRepository repository;
  final HealthProfile profile;

  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _height = TextEditingController(
    text: widget.profile.heightCm?.toString(),
  );
  final _weight = TextEditingController();
  late String? _sex = widget.profile.sex;
  late int? _srpa = widget.profile.srpa;
  bool _srpaChanged = false;
  late String? _birthday = widget.profile.dobDate;
  bool _saving = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      const Text(
        'Your measurements help personalize estimates. Unanswered fields stay unknown.',
      ),
      StateCard(child: Column(children: _bodyFields())),
      ActivityLevelField(
        value: _srpa,
        enabled: !_saving,
        onChanged: (value) => setState(() {
          _srpa = value;
          _srpaChanged = true;
        }),
      ),
      if (widget.profile.bmi != null)
        Text(
          'BMI from stored height and weight: ${widget.profile.bmi} kg/m² · weight dated ${widget.profile.weightAsOf ?? 'unknown'}. BMI does not measure body composition.',
        ),
      StateCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.profile.weightKg == null
                  ? 'No weight recorded'
                  : 'Last recorded: ${widget.profile.weightKg} kg · ${widget.profile.weightAsOf ?? 'date unavailable'}',
            ),
            TextField(
              controller: _weight,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'New weigh-in today (optional)',
                suffixText: 'kg',
              ),
            ),
          ],
        ),
      ),
      if (_notice != null) Semantics(liveRegion: true, child: Text(_notice!)),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save profile'),
      ),
    ];
    return ListView.separated(
      itemCount: sections.length,
      separatorBuilder: (context, index) => const SizedBox(height: Insets.lg),
      itemBuilder: (context, index) => sections[index],
    );
  }

  List<Widget> _bodyFields() => [
    TextField(
      controller: _name,
      enabled: !_saving,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Name'),
    ),
    TextField(
      controller: _height,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm'),
    ),
    DropdownButton<String>(
      value: _sex,
      isExpanded: true,
      hint: const Text('Sex used by the estimates'),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
      ],
      onChanged: _saving ? null : (value) => setState(() => _sex = value),
    ),
    TextButton(
      onPressed: _saving ? null : _pickBirthday,
      child: Text(
        _birthday ??
            (widget.profile.legacyBirthdayPresent
                ? 'Birthday stored on server · tap to confirm'
                : 'Enter date of birth'),
      ),
    ),
  ];

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday == null ? now : DateTime.parse(_birthday!),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _birthday = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _save() async {
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    if (!_validNumber(_height.text, height, 300) ||
        !_validNumber(_weight.text, weight, 500)) {
      setState(
        () => _notice =
            'Enter a valid positive height or weight, or leave it blank.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      await widget.repository.save(
        name: _name.text,
        heightCm: height,
        sex: _sex,
        dobDate: _birthday,
        srpa: _srpa,
        updateSrpa: _srpaChanged,
        measuredWeightKg: weight,
      );
      if (!mounted) return;
      _weight.clear();
      ref.invalidate(healthProfileProvider);
      ref.invalidate(todaySnapshotProvider);
      setState(
        () => _notice =
            'Saved. Daily estimates refresh with subsequent analysis.',
      );
    } on Exception catch (error, stack) {
      AppLog.failure('profile', 'saving profile', error, stack);
      if (mounted) {
        setState(
          () => _notice =
              'Save could not be confirmed. Your form is still here; check your connection and server version.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validNumber(String text, double? value, double maximum) =>
      text.trim().isEmpty ||
      (value != null && value.isFinite && value > 0 && value <= maximum);
}
