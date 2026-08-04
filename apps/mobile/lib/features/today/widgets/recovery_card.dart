/// Recovery 0–100 — one of the five approved composites, and only because it
/// always ships its own breakdown.
///
/// `docs/APP_DESIGN.md` §1 approves this score specifically because it "always
/// renders its per-factor breakdown", and `feedback_no_composite_score` is the
/// standing rule behind that. So the sub-scores are not an optional detail
/// panel: they are the licence for the headline number, and they are drawn
/// beside it, always.
///
/// [RecoveryScore.guidance] is rendered **verbatim**. It is deterministic and
/// rule-based rather than LLM-written, and — the part that matters — an active
/// illness flag OVERRIDES its text. Re-wording it in the UI would re-word a
/// safety message written somewhere with access to the evidence.
///
/// A factor with a null sub-score keeps its row and draws no bar. A missing
/// signal is a real state; a zero bar would say the signal was measured and was
/// terrible.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/features/today/widgets/measured_card.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// The recovery headline with its per-factor breakdown.
class RecoveryCard extends StatelessWidget {
  /// Renders [score].
  const RecoveryCard({required this.score, super.key});

  /// The day's recovery, readiness and factors.
  final RecoveryScore score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recovery', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              HeroValue(value: '${score.recovery}', unit: 'of 100'),
              const Spacer(),
              if (score.readiness case final int readiness)
                Text(
                  'Readiness $readiness',
                  style: text.labelMedium?.copyWith(color: colors.ink2),
                ),
            ],
          ),
          if (score.guidance case final String guidance) ...[
            const SizedBox(height: Insets.md),
            // Verbatim — an illness flag overrides this text.
            Text(guidance, style: text.bodyLarge),
          ],
          const SizedBox(height: Insets.lg),
          Text('What it is made of', style: text.labelSmall),
          for (final factor in score.factors) ...[
            const SizedBox(height: Insets.sm),
            _FactorRow(factor: factor),
          ],
          const SizedBox(height: Insets.md),
          CitationRow(
            noteIds: [if (score.noteId case final String id) id],
          ),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final RecoveryFactor factor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final sub = factor.subScore;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(_label(factor.name), style: text.bodySmall),
        ),
        Expanded(
          child: sub == null
              // No bar at all. A zero-width bar and a zero score look identical.
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: ValueHole(width: 56, height: 8, radius: Radii.pill),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Expanded(
                          flex: sub.clamp(0, 100),
                          child: ColoredBox(color: colors.accent),
                        ),
                        Expanded(
                          flex: (100 - sub).clamp(0, 100),
                          child: ColoredBox(color: colors.line2),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(width: Insets.md),
        SizedBox(
          width: 58,
          child: Text(
            sub == null ? 'no signal' : '$sub${_weight(factor)}',
            textAlign: TextAlign.right,
            style: text.labelMedium?.copyWith(color: colors.ink2),
          ),
        ),
      ],
    );
  }

  static String _weight(RecoveryFactor factor) {
    final weight = factor.weight;
    return weight == null ? '' : ' · ${(weight * 100).round()}%';
  }

  static String _label(String name) => switch (name) {
    'hrv' => 'HRV',
    'rhr' => 'Resting HR',
    'rr' => 'Breathing',
    'sleep' => 'Sleep',
    _ => name,
  };
}
