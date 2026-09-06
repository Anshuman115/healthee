/// `Strength · this week` — the half of the activity guideline nothing drew.
///
/// **Not a legacy card.** `read/fitness.py::strength_payload` has been computing
/// this and legacy referenced it in a single file; Today never showed it. It is
/// added deliberately, and it wears legacy's language throughout — the same
/// `HModule`, the same 40 px figure over a target, the same `HProgressBar`, the
/// same three-column stat row as the MVPA card it sits beside — so it does not
/// read as a foreign object.
///
/// ```text
///   STRENGTH · THIS WEEK                          this week
///   45  / 30–60 min                                    150%
///   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬
///   SESSIONS   OF TARGET   KINDS
///       1        150%      strength
/// ```
///
/// ## Where it sits, and why
///
/// Directly under `Active minutes · MVPA`, in the Activity section. They are the
/// two halves of one recommendation — moderate-to-vigorous minutes *and*
/// muscle-strengthening on two or more days — and splitting them across the
/// screen would let the owner read the first as the whole of it.
///
/// ## The target is a BAND, and the bar is against its floor
///
/// [[strength_training_mortality]] (Momma 2022) finds the benefit peaks around
/// 30–60 minutes a week and does **not** keep improving above it. So the label
/// says `/ 30–60 min` rather than `/ 60 min`, and the percentage is against the
/// floor — reaching 30 is the claim the evidence supports, and a bar that only
/// filled at 60 would tell the owner they had failed at 45.
///
/// A week at zero renders. A payload with no `strength` block does not — see
/// `data/models/strength.dart`.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/strength.dart';
import 'package:healthee/features/today/widgets/stat_columns.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/citation_row.dart';

/// The week's strength minutes against the band the evidence supports.
class StrengthCard extends StatelessWidget {
  /// [strength] is the whole `strength` block.
  const StrengthCard({required this.strength, required this.reveals, super.key});

  /// The week's minutes, sessions and target band.
  final Strength strength;

  /// Where "this bar has already animated" is remembered.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // `cReady` — the hue legacy gives training load and fitness, which is what
    // this is. It is the same value as the accent in both themes.
    final tint = context.hues.fitness;
    final floor = strength.targetLowMin;
    final percent = floor == 0 ? 0 : (strength.weekMin / floor * 100).round();
    return InstrumentModule(
      label: 'Strength · this week',
      tag: tint,
      minHeight: 0,
      trailing: Text(
        'this week',
        style: HType.number(colors.ink3, size: 10, weight: FontWeight.w400),
      ),
      children: [
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${strength.weekMin}',
              style: HType.number(
                colors.ink,
                size: 40,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '/ ${strength.targetLowMin}–${strength.targetHighMin} min',
              style: HType.number(
                colors.ink3,
                size: 13,
                weight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: HType.number(tint, size: 16, weight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RevealOnce(
          id: 'today.strength',
          registry: reveals,
          builder: (context, t) => HProgressBar(
            value: strength.weekMin.toDouble(),
            max: floor.toDouble(),
            progress: t,
            height: 6,
            color: tint,
            semanticLabel:
                '${strength.weekMin} of $floor strength minutes this week',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            StatColumn(label: 'SESSIONS', value: '${strength.sessions}'),
            StatColumn(label: 'OF TARGET', value: '$percent%'),
            StatColumn(
              label: 'KINDS',
              // The kinds are the evidence for the minutes. With none, an em
              // dash and not a zero — nothing was categorised, which is not the
              // same as nothing counting.
              value: strength.types.isEmpty ? '—' : strength.types.join(' · '),
            ),
          ],
        ),
        if (strength.researchNote case final String note) ...[
          const SizedBox(height: 12),
          CitationRow(noteIds: [note]),
        ],
      ],
    );
  }
}
