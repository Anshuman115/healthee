/// Recovery 0–100, drawn as legacy's readiness instrument: a gauge and its parts.
///
/// **Ported from** `design_reference/project/hh/screen_today.jsx`'s
/// `ReadinessBlock` — a tick gauge on the left carrying the figure and its band,
/// and on the right a label over four rows of `label · mini meter · value`. The
/// geometry is legacy's; the colour and type are this app's.
///
/// ## The breakdown is not a detail panel, it is the licence
///
/// `docs/APP_DESIGN.md` §1 approves this score as one of five composites
/// specifically because it "always renders its per-factor breakdown", and
/// `feedback_no_composite_score` is the standing rule behind that. Legacy's
/// layout happens to be the right shape for it: the factors are not below a fold
/// or behind a tap, they are physically beside the number and take up more of the
/// card than it does.
///
/// A factor with a null sub-score keeps its row and draws **no bar** — [HMeter]
/// enforces that. A missing signal is a real state; a zero-width bar and a score
/// of zero look identical and mean opposite things.
///
/// ## Where the guidance sentence went
///
/// It used to be rendered here. It is now rendered once, by `GreetingBlock`, at
/// the top of the screen — which is exactly where legacy puts its editorial line
/// and is a better home for a sentence than the middle of an instrument. It is
/// still verbatim, and still the string an illness flag overrides. Two copies of
/// a safety message on one screen is one copy that can drift.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/features/today/widgets/instrument_module.dart';
import 'package:healthee/shared/charts/h_meter.dart';
import 'package:healthee/shared/charts/h_tick_gauge.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The recovery gauge with its per-factor breakdown beside it.
class RecoveryCard extends StatelessWidget {
  /// [reveals] must be the screen's registry, not one built here.
  const RecoveryCard({required this.score, required this.reveals, super.key});

  /// The day's recovery, readiness and factors.
  final RecoveryScore score;

  /// Where "this gauge has already animated" is remembered.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    // The tag for rest, not a judgement colour: the gauge is a picture of a
    // score, and tinting it by how good the score is would be the app grading
    // the owner in colour. See palette.dart.
    final tag = context.hues.rest;
    return StateCard(
      child: RevealOnce(
        id: 'today.recovery',
        registry: reveals,
        builder: (context, t) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                HTickGauge(
                  value: score.recovery.toDouble(),
                  color: tag,
                  progress: t,
                  child: _GaugeCentre(score: score, tag: tag),
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ModuleLabel('What it is made of'),
                      const SizedBox(height: Insets.md),
                      for (final factor in score.factors)
                        _FactorRow(factor: factor, tag: tag, progress: t),
                    ],
                  ),
                ),
              ],
            ),
            if (score.readiness case final int readiness) ...[
              const SizedBox(height: Insets.md),
              Text(
                'Readiness $readiness — what is left of that after the strain '
                'today has already spent.',
                style: text.bodySmall?.copyWith(color: colors.ink3),
              ),
            ],
            const SizedBox(height: Insets.md),
            CitationRow(noteIds: [if (score.noteId case final String id) id]),
          ],
        ),
      ),
    );
  }
}

/// The figure inside the arc, and the server's band under it.
class _GaugeCentre extends StatelessWidget {
  const _GaugeCentre({required this.score, required this.tag});

  final RecoveryScore score;
  final Color tag;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${score.recovery}',
          style: text.displayLarge?.copyWith(fontSize: 36, height: 0.95),
        ),
        if (bandLabel(score.band) case final String band) ...[
          const SizedBox(height: 3),
          ModuleLabel(band, color: tag),
        ],
      ],
    );
  }
}

/// The owner-facing name for a server band.
///
/// Legacy printed "PRIMED" here, which is a word of its own invention about how
/// the owner should feel. These are the server's three categories renamed to
/// English and nothing more — `high` sets a high intensity ceiling for the day,
/// it does not promise the owner is primed. An unrecognised band draws nothing
/// rather than a guess.
String? bandLabel(String? band) => switch (band) {
  'high' => 'High',
  'moderate' => 'Moderate',
  'low' => 'Low',
  _ => null,
};

/// `HRV · ▬▬▬▬▭▭ · 80` — legacy's contributor row.
class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor, required this.tag, required this.progress});

  final RecoveryFactor factor;
  final Color tag;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final sub = factor.subScore;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          SizedBox(width: 80, child: ModuleLabel(factorLabel(factor.name))),
          const SizedBox(width: 9),
          Expanded(
            child: HMeter(
              fraction: sub == null ? null : sub / 100,
              color: tag,
              progress: progress,
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 26,
            child: Text(
              // Words, not a zero. A dash would be read as a value.
              sub == null ? 'n/a' : '$sub',
              textAlign: TextAlign.right,
              style: text.labelMedium?.copyWith(
                color: sub == null ? colors.ink3 : colors.ink,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner-facing name for a factor id, as the server sends it.
String factorLabel(String name) => switch (name) {
  'hrv' => 'HRV',
  'rhr' => 'Resting HR',
  'rr' => 'Breathing',
  'sleep' => 'Sleep',
  _ => name,
};
