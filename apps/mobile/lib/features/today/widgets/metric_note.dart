/// The one-line research note under legacy's HRV and blood-oxygen modules.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart` —
/// `_MetricInsight` (54), `_hrvNote` (22) and `_spo2Note` (35). The sentences
/// below are legacy's, word for word, including their thresholds.
///
/// ## What is NOT ported, and why the card still looks the same
///
/// Legacy's `_MetricInsight` watches `metricInsightProvider`, which calls
/// `GET /api/metric/insight` — a per-metric, per-day, LLM-written line — and
/// falls back to the static sentence *"while it loads or if unavailable — so
/// it's instant and never blank"*. The static sentence is therefore what the card
/// renders on every cold read, and it is what renders here.
///
/// The LLM half is not wired: this app has no client for that endpoint, and
/// adding one is a data-layer feature rather than a screen port. The widget is
/// shaped so that wiring it later is one optional argument. Reported.
///
/// ## The thresholds are legacy's, and they are claims
///
/// ±12% against the 30-day median for HRV; 90% and 92% for a nightly SpO₂
/// minimum. They are not re-derived here and they are not softened — a port that
/// quietly moved a clinical threshold would be a behaviour change hiding inside
/// a layout change.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The static note under a metric's trend chart.
class MetricNote extends StatelessWidget {
  /// [text] is already chosen by [hrvNote] or [spo2Note].
  const MetricNote(this.text, {super.key});

  /// The sentence.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text,
      style: HType.sans(colors.ink3, size: 11.5, height: 1.45),
    );
  }
}

/// Legacy's `_hrvNote` — how last night's HRV sits against the owner's median.
String hrvNote(double? current, double? median) {
  if (current == null || median == null || median == 0) {
    return 'Overnight HRV is your vagal-recovery signal — trends matter far '
        'more than any single night.';
  }
  final percent = (current - median) / median * 100;
  if (percent <= -12) {
    return 'Below your recent baseline. Evening alcohol, short or poor sleep, '
        'late caffeine, or a hard workout the day before can each drop '
        'overnight HRV — check what changed yesterday.';
  }
  if (percent >= 12) {
    return 'Above your recent baseline — good autonomic recovery.';
  }
  return 'In line with your recent baseline.';
}

/// Legacy's `_spo2Note` — what the nightly minimum says, not the average.
String spo2Note(double? average, double? lastMinimum, double? lowest) {
  if (average == null) {
    return 'Overnight blood-oxygen is normally 95–100%. The nightly LOW matters '
        'more than the average — repeated dips can signal disrupted breathing '
        'during sleep.';
  }
  if (lowest != null && lowest < 90) {
    return 'A night dipped to ${lowest.round()}% — below 90% is worth noting. '
        'Occasional dips happen, but a recurring pattern of low nightly '
        'minimums is the signal to watch (and to raise with a clinician).';
  }
  if (lastMinimum != null && lastMinimum < 92) {
    return "Last night's low was ${lastMinimum.round()}%. One-off dips are "
        'usually benign; watch whether the nightly minimum keeps falling.';
  }
  return 'Healthy overnight oxygen — averages in the normal 95–100% range with '
      'steady nightly lows.';
}
