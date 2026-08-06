/// The sleep gauge that opens legacy's Sleep section.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:560` —
/// `_ReadinessBlock`. An 18 px-padded module with no header, a 116 px tick gauge
/// on the left carrying the device's own sleep score, and on the right the
/// night's label, a one-word verdict at 24 px, and the duration.
///
/// ```text
///   ╭────╮   LAST NIGHT
///   │ 86 │   Strong
///   ╰────╯   6h 20m · device sleep score
///    SLEEP
/// ```
///
/// The number is the **strap's own score**, not a composite this app computed —
/// which is why the line under the verdict names it as such.
///
/// ## Two legacy behaviours, one ported and one refused
///
/// **Ported:** the four bands (80 / 65 / 50) and their words, unchanged.
///
/// **Refused:** legacy computes `final score = sleepScore ?? 0`, so a night with
/// no score renders the word **"Low"** — a verdict on a measurement that does not
/// exist, drawn beside a gauge showing an em dash. This is exactly what
/// `Reading` exists to stop. With no score the gauge draws a [ValueHole] and the
/// verdict is omitted; the night's label and duration still render, because those
/// are real. The one card that must never flatter must also never accuse.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/charts/h_tick_gauge.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// The device's sleep score, its verdict word, and the night it describes.
class ReadinessBlock extends StatelessWidget {
  /// [sleepScore] is the strap's, 0–100, or null when the night was not scored.
  const ReadinessBlock({
    required this.sleepScore,
    required this.durationMin,
    required this.nightLabel,
    required this.reveals,
    super.key,
  });

  /// The strap's own score for the night.
  final int? sleepScore;

  /// Total sleep time, and what the server was willing to say about it.
  final Reading<int> durationMin;

  /// "Last night" · "Night before last" · "3 nights ago".
  final String nightLabel;

  /// Where "this gauge has already animated" is remembered.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = context.hues.sleep;
    final minutes = durationMin.valueOrNull;
    return InstrumentModule(
      label: '',
      tag: null,
      minHeight: 0,
      padding: const EdgeInsets.all(18),
      children: [
        RevealOnce(
          id: 'today.sleep-score',
          registry: reveals,
          builder: (context, t) => Row(
            children: [
              HTickGauge(
                // Legacy passes the score straight in; with none there is nothing
                // to light, and an unlit arc is the honest picture of that.
                value: (sleepScore ?? 0).toDouble(),
                size: 116,
                color: tint,
                progress: t,
                child: _GaugeCentre(score: sleepScore, tint: tint),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModuleLabel(nightLabel),
                    const SizedBox(height: 8),
                    if (verdictWord(sleepScore) case final String word) ...[
                      Text(word, style: HType.serif(tint, size: 24)),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      '${minutes == null ? '—' : hoursMinutes(minutes)} · '
                      'device sleep score',
                      style: HType.sans(colors.ink3, size: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Legacy's four bands. Null for an unscored night — see the library docstring.
String? verdictWord(int? score) {
  if (score == null) {
    return null;
  }
  if (score >= 80) {
    return 'Strong';
  }
  if (score >= 65) {
    return 'Good';
  }
  if (score >= 50) {
    return 'Fair';
  }
  return 'Low';
}

class _GaugeCentre extends StatelessWidget {
  const _GaugeCentre({required this.score, required this.tint});

  final int? score;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 74,
          child: score == null
              ? const Center(child: ValueHole(width: 46, height: 26))
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$score',
                    style: HType.number(colors.ink, size: 36),
                  ),
                ),
        ),
        Text(
          'SLEEP',
          style: HType.label(tint, size: 9, tracking: 0.16),
        ),
      ],
    );
  }
}
