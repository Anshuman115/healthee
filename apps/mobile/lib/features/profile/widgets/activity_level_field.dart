/// Usual activity — Jurca's NASA Table 1 categories, in v02's `.field`.
///
/// **The five labels are science, not copy, and they are unchanged.** They are
/// the reference levels the non-exercise VO₂max model was fitted against
/// (`packages/knowledge` → `non_exercise_vo2max`), so editing them for brevity
/// would silently move the owner between levels the model was calibrated on.
/// `feedback_verify_primary_sources` and CLAUDE.md's *"science code is sacred"*
/// both land on the same rule.
///
/// **It is never inferred from steps and never auto-filled.** The self-report is
/// a different instrument from the strap's step count, and the whole reason the
/// question is asked is that everyday walking does not answer it. An unanswered
/// menu stays unanswered — `HSelect.placeholder` is *"Not answered"*, never a
/// guessed default, because a guess here changes a published VO₂max.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/fields.dart';

/// The self-reported activity level the fitness estimate reads.
class ActivityLevelField extends StatelessWidget {
  /// Builds the field. A null [value] renders as unanswered.
  const ActivityLevelField({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  /// Jurca NASA Table 1, verbatim. See the library docstring.
  static const List<String> labels = <String>[
    'Little activity beyond walking for pleasure',
    'Some regular modest sports or recreational activity',
    'Aerobic exercise: 20–60 minutes per week',
    'Aerobic exercise: 1–3 hours per week',
    'Aerobic exercise: more than 3 hours per week',
  ];

  /// The chosen level, or null when the owner has not answered.
  final int? value;

  /// False while a save is in flight.
  final bool enabled;

  /// Sets it. Called with null when the answer is cleared.
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      HField(
        label: 'Usual activity',
        hint:
            'Your self-report, separate from strap measurements. Choose the '
            'closest description of a typical week; everyday steps do not '
            'answer it.',
        child: HSelect<int>(
          value: value,
          placeholder: 'Not answered',
          onChanged: enabled ? onChanged : null,
          items: <(int, String)>[
            for (var i = 0; i < labels.length; i++) (i, labels[i]),
          ],
        ),
      ),
      if (value != null)
        HButton(
          label: 'Clear answer',
          kind: HButtonKind.soft,
          onPressed: enabled ? () => onChanged(null) : null,
        ),
      const CitationRow(noteIds: ['non_exercise_vo2max']),
    ],
  );
}
