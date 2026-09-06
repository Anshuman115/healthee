import 'package:flutter/material.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Jurca NASA Table 1 categories; never inferred from steps or auto-filled.
class ActivityLevelField extends StatelessWidget {
  const ActivityLevelField({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  static const labels = [
    'Little activity beyond walking for pleasure',
    'Some regular modest sports or recreational activity',
    'Aerobic exercise: 20–60 minutes per week',
    'Aerobic exercise: 1–3 hours per week',
    'Aerobic exercise: more than 3 hours per week',
  ];
  @override
  Widget build(BuildContext context) => StateCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your usual deliberate exercise'),
        const Text(
          'Choose the closest description of a typical week. This is a self-report used by the fitness estimate; everyday steps do not answer it.',
        ),
        DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: const Text('Not answered'),
          items: [
            for (var i = 0; i < labels.length; i++)
              DropdownMenuItem(value: i, child: Text(labels[i], maxLines: 2)),
          ],
          onChanged: enabled ? onChanged : null,
        ),
        if (value != null)
          TextButton(
            onPressed: enabled ? () => onChanged(null) : null,
            child: const Text('Clear answer'),
          ),
        const CitationRow(noteIds: ['non_exercise_vo2max']),
      ],
    ),
  );
}
