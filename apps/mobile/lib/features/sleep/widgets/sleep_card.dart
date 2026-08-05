/// Last night as the strap staged it — four measured spans, no judgement.
///
/// The stage bar is a picture of the record and nothing more: four widths in
/// proportion to four minute counts the device itself summed. There is no score,
/// no cutoff line and no verdict on the night, because all three of those are
/// the server's four-dimension sleep-health judgement and this app must not
/// grow a second one (`docs/APP_DESIGN_BRIEF.md` §4.2 names the cutoffs; they
/// live where the derivation does).
///
/// The strap's OWN score is shown, small and attributed. It is a number the
/// owner can already read on their wrist, so hiding it would be its own small
/// dishonesty — but it is labelled as the strap's in the same breath, because
/// two sleep scores under one word would be exactly the failure CLAUDE.md warns
/// about.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_night.dart';
import 'package:healthee/shared/charts/h_stage_bar.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/measured_card.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// Last night's record, as measured.
class SleepCard extends StatelessWidget {
  /// [now] is injected so tests do not depend on the wall clock.
  const SleepCard({required this.day, this.now, super.key});

  /// The day being shown.
  final DeviceDay day;

  /// The current instant.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    // The same tag the server-staged night card wears, from the same table —
    // this card is its fallback, and two cards for one night in two colours
    // would look like two different nights.
    final tag = context.hues.tagFor('sleep_duration');
    return ReadingView<DeviceNight>(
      reading: day.lastNight,
      label: 'Last night',
      builder: (context, night) => MeasuredCard(
        title: 'Last night',
        tag: tag,
        measuredAt: night.end,
        now: now,
        footnote: _footnote(night),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroValue(
              value: durationLabel(night.asleepMin),
              unit: 'asleep',
              tag: tag,
            ),
            const SizedBox(height: Insets.md),
            _StageBar(night: night),
          ],
        ),
      ),
    );
  }

  /// The times, the awake minutes, and the strap's own score — attributed.
  static String _footnote(DeviceNight night) {
    final parts = <String>[
      '${clockLabel(night.start)} → ${clockLabel(night.end)}',
      '${night.wakeMin} min awake in bed',
    ];
    if (night.avgHr > 0) {
      parts.add('${night.avgHr} bpm average');
    }
    if (night.hasDeviceScore) {
      // Named as the strap's, every time. Healthee's sleep judgement is the
      // server's four dimensions and is withheld on this build.
      parts.add("${night.deviceScore}/100 by the strap's own score");
    }
    return parts.join(' · ');
  }
}

/// The stage proportions and their minutes, under the night's total.
///
/// The bar itself is [HStageBar] — the same widget the Today grid's sleep cell
/// draws. It was a private copy here, and the copy carried a layout bug the
/// shared one has a test for: its segments laid out at zero height, so the bar
/// was invisible on a real render. Standards §1: second occurrence = extract.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.night});

  final DeviceNight night;

  /// The device's minutes per stage, in record order.
  Map<String, int> get _minutes => <String, int>{
    'deep': night.deepMin,
    'light': night.lightMin,
    'rem': night.remMin,
    'awake': night.wakeMin,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (night.inBedMin <= 0) {
      return const SizedBox.shrink();
    }
    final minutes = _minutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Not animated: this card is the strap-only fallback and draws no
        // reveal registry of its own, so the bar arrives finished.
        HStageBar(minutes, progress: 1),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.md,
          children: [
            for (final stage in kSleepStages)
              if ((minutes[stage] ?? 0) > 0)
                Text(
                  '${sleepStageLabel(stage)} ${durationLabel(minutes[stage]!)}',
                  style: text.labelSmall?.copyWith(color: colors.ink3),
                ),
          ],
        ),
      ],
    );
  }
}
