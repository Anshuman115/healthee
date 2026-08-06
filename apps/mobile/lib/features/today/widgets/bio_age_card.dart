/// `Biological age · estimate` — the headline, and the per-term waterfall.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1133` —
/// `_BioAgeModule`. Anatomy unchanged: a 44 px figure with `vs N actual` beside
/// it, the signed delta as a sentence, one row per contribution (a 116 px label
/// column, a 6 px bar scaled to the largest absolute contribution, and the signed
/// years), and the disclaimer under an info icon.
///
/// ```text
///   BIOLOGICAL AGE · ESTIMATE                          ●
///   34   vs 36 actual
///   1.7 years younger
///   Fitness        ▬▬▬▬▬▬▬▬▬▬▬▬     −1.7y
///   43.0 → 40
///   Sleep duration ▬▬▬▬              +0.6y
///   ⓘ Motivational estimate from population data — not a clinical age.
/// ```
///
/// The bar length is `|delta| / max|delta|`, so the rows are readable against
/// each other and never against an absolute scale nobody has.
///
/// ## The disclaimer, and the half of legacy's sentence that is dropped
///
/// Legacy prints *"Motivational estimate from population data — not a clinical
/// age. Tap ⓘ for the method."* The second sentence points at
/// `metric_info.dart`'s explainer sheet, which is not in this rebuild, so it is
/// not printed — a pointer at a place the reader cannot reach is worse than no
/// pointer. The first sentence is the payload's own `disclaimer` field where the
/// server sent one, and legacy's literal where it did not.
///
/// The terms the server **excluded** ride on the reading as caveats and are
/// rendered by `ReadingView` above this card, which is where a `Caveated` value's
/// disclosures belong. Legacy has no surface for them at all.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:solar_icons/solar_icons.dart';

/// The estimate, its terms, and what it is not.
class BioAgeCard extends StatelessWidget {
  /// [age] is the whole `biological_age` block.
  const BioAgeCard({required this.age, required this.reveals, super.key});

  /// The estimate and its contributions.
  final BiologicalAge age;

  /// Where "these bars have already animated" is remembered.
  final RevealRegistry reveals;

  /// Legacy's threshold for calling the delta a direction at all.
  static const double meaningfulYears = 0.5;

  /// Legacy's fallback disclaimer, minus its pointer at the explainer sheet.
  static const String defaultDisclaimer =
      'Motivational estimate from population data — not a clinical age.';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final delta = age.deltaYears ?? 0;
    final older = delta > meaningfulYears;
    final younger = delta < -meaningfulYears;
    final deltaColor = older
        ? colors.alert
        : younger
        ? colors.accent
        : colors.ink3;
    var widest = 1.0;
    for (final contribution in age.contributions) {
      final size = (contribution.deltaYears ?? 0).abs();
      if (size > widest) {
        widest = size;
      }
    }
    return InstrumentModule(
      label: 'Biological age · estimate',
      tag: context.hues.readiness,
      infoKey: 'biological_age',
      minHeight: 0,
      children: [
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              age.biologicalAge.round().toString(),
              style: HType.number(
                colors.ink,
                size: 44,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            if (age.chronologicalAge case final double actual)
              Text(
                'vs ${actual.round()} actual',
                style: HType.number(
                  colors.ink3,
                  size: 13,
                  weight: FontWeight.w400,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          older
              ? '${delta.abs().toStringAsFixed(1)} years older'
              : younger
              ? '${delta.abs().toStringAsFixed(1)} years younger'
              : 'about your real age',
          style: HType.sans(deltaColor, size: 14, weight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        RevealOnce(
          id: 'today.bio-age',
          registry: reveals,
          builder: (context, t) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final contribution in age.contributions)
                _ContributionRow(
                  contribution: contribution,
                  widest: widest,
                  progress: t,
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(SolarIconsOutline.infoCircle, size: 13, color: colors.ink3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                age.disclaimer ?? defaultDisclaimer,
                style: HType.sans(colors.ink3, size: 11.5, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One term of the estimate: what it is, how far it moves the number, and where
/// the owner's value sits against the target.
class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.widest,
    required this.progress,
  });

  final AgeContribution contribution;
  final double widest;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final years = contribution.deltaYears ?? 0;
    final tint = years > 0
        ? colors.alert
        : years < 0
        ? colors.accent
        : colors.ink3;
    final detail = contribution.value == null
        ? null
        : '${contribution.value}${(contribution.unit ?? '').contains('h/') ? 'h' : ''}'
              ' → ${contribution.target}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  termLabel(contribution.term),
                  style: HType.sans(
                    colors.ink,
                    size: 13,
                    weight: FontWeight.w600,
                  ),
                ),
                if (detail case final String line) ...[
                  const SizedBox(height: 1),
                  Text(
                    line,
                    style: HType.number(
                      colors.ink3,
                      size: 9.5,
                      weight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(height: 6, color: colors.surface2),
                  FractionallySizedBox(
                    widthFactor:
                        ((years.abs() / widest) * progress).clamp(0.0, 1.0),
                    child: Container(height: 6, color: tint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '${years >= 0 ? '+' : ''}${years.toStringAsFixed(1)}y',
              textAlign: TextAlign.right,
              style: HType.number(tint, size: 12, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner-facing name for a term. Legacy's `_termLabel` (1137).
///
/// The `_` fallback is legacy's: an unknown term prints its own id, which keeps
/// a term the server grew visible rather than silently unnamed.
String termLabel(String term) => switch (term) {
  'fitness' => 'Fitness',
  'sleep duration' => 'Sleep duration',
  'regularity' => 'Sleep timing',
  _ => term,
};
