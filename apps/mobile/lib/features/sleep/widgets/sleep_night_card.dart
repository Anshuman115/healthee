/// Last night: how long, the shape of it, and what the strap measured through it.
///
/// The hypnogram is the chart that earns its place here — a total says "six
/// hours twenty", the shape says whether that was one settled block or five
/// fragments, and only one of those two is actionable.
///
/// The strap's own score is shown and **attributed in the same breath**. It is a
/// number the owner can already read on their wrist, so hiding it would be its
/// own small dishonesty; presenting it as Healthee's judgement would be a much
/// larger one, because Healthee's judgement is the four-dimension breakdown in
/// the next card and two scores under one word is the failure CLAUDE.md names
/// first.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/shared/charts/h_hypnogram.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/measured_card.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Last night's duration, hypnogram, stage totals and overnight vitals.
class SleepNightCard extends StatelessWidget {
  /// [vitals] may be null when the strap measured nothing overnight.
  const SleepNightCard({
    required this.night,
    required this.reveals,
    this.vitals,
    super.key,
  });

  /// The night as the server staged it.
  final LastSleep night;

  /// The screen's reveal registry — outlives this list item, which is the point.
  final RevealRegistry reveals;

  /// What the strap measured while the owner slept.
  final OvernightVitals? vitals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last night', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          HeroValue(value: durationLabel(night.durationMin), unit: 'asleep'),
          const SizedBox(height: Insets.xs),
          Text(
            _window(night),
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          if (night.stages.isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            RevealOnce(
              id: 'sleep-hypnogram-${night.startIso}',
              registry: reveals,
              builder: (context, t) => HHypnogram(night.stages, progress: t),
            ),
            const SizedBox(height: Insets.sm),
            _StageLegend(night: night),
          ],
          if (vitals case final OvernightVitals measured) ...[
            Divider(color: colors.line2, height: Insets.xl, thickness: hairline),
            Text('Through the night', style: text.labelSmall),
            const SizedBox(height: Insets.sm),
            _VitalsGrid(vitals: measured),
          ],
        ],
      ),
    );
  }

  /// The window and the strap's own score, attributed.
  static String _window(LastSleep night) {
    final parts = <String>[
      if (_clock(night.startIso) case final String from)
        if (_clock(night.endIso) case final String to) '$from → $to',
      if (night.avgHr case final int hr) '$hr bpm average',
      if (night.score case final int score)
        "$score/100 by the strap's own score",
    ];
    return parts.join(' · ');
  }

  /// `HH:MM` out of an ISO string carrying the owner's own offset, without
  /// turning it into an instant in the device's zone.
  static String? _clock(String? iso) =>
      iso != null && iso.length >= 16 ? iso.substring(11, 16) : null;
}

class _StageLegend extends StatelessWidget {
  const _StageLegend({required this.night});

  final LastSleep night;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: Insets.md,
      runSpacing: Insets.xs,
      children: [
        for (final stage in kSleepStages)
          if (night.minutesIn(stage) > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: Insets.xs),
                  decoration: BoxDecoration(
                    color: sleepStageColor(colors, context.hues, stage),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                Text(
                  '${sleepStageLabel(stage)} '
                  '${durationLabel(night.minutesIn(stage))}',
                  style: text.labelSmall?.copyWith(color: colors.ink3),
                ),
              ],
            ),
      ],
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.vitals});

  final OvernightVitals vitals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final entries = <(String, String)>[
      if (vitals.hrvRmssdMs case final double hrv)
        ('HRV', '${hrv.round()} ms'),
      if (vitals.respiratoryRate case final double rate)
        ('Breathing', '${rate.round()} /min'),
      if (vitals.skinTempC case final double temp)
        ('Skin temp', '${temp.toStringAsFixed(1)} °C'),
    ];
    return Wrap(
      spacing: Insets.xl,
      runSpacing: Insets.sm,
      children: [
        for (final (label, value) in entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: text.labelSmall?.copyWith(color: colors.ink3)),
              Text(value, style: text.titleMedium),
            ],
          ),
      ],
    );
  }
}
