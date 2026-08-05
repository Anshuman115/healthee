/// `Insights` — the correlations found in the owner's own data.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1512` —
/// `_InsightsSection`, `_describeFinding` (1477), `_trivialFinding` (1497) and
/// `_metricFriendly` (1467). One `Pattern` module per finding, at most four, each
/// with the strength in the header, the sentence at display size, and `r 0.62 ·
/// 105 days of your data` as its foot.
///
/// ```text
///   PATTERN                                    VERY CONSISTENT
///   When your HRV is higher, your steps are usually higher the next day.
///   R 0.71 · 105 DAYS OF YOUR DATA
/// ```
///
/// ## The trivial filter is doing real work and is ported exactly
///
/// `_trivialFinding` drops pairs that are definitionally derived from each other
/// — two activity metrics (all of which come from the same step stream), two
/// sleep-dimension metrics, a sleep dimension against regularity, and **any pair
/// with |r| ≥ 0.97**, which legacy annotates `near-perfect = definitional`. Every
/// one of those would otherwise read as a discovery about the owner rather than
/// as arithmetic.
///
/// ## What legacy's sign does and does not say, and why no colour is spent
///
/// The header chip is the accent at every strength and the row draws no verdict
/// colour at all. That is legacy's (`today_screen.dart:1540`), and it is the
/// restraint `apps/mobile/README.md` describes: the sign of a rank correlation
/// says *moved together* or *moved opposite*, which is a direction and not a
/// verdict, and a q-corrected correlation over one person's history cannot
/// support "this is good for you".
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/shared/instrument_module.dart';

/// At most four non-trivial patterns, or the sentence that says there are none.
class InsightsSection extends StatelessWidget {
  /// [findings] is `top_findings`, in server order.
  const InsightsSection({required this.findings, super.key});

  /// Every finding the server raised.
  final List<Finding> findings;

  /// Legacy's `.take(4)`.
  static const int maxShown = 4;

  /// The sentence when nothing survives the filter.
  static const String nothingYet =
      'No clear patterns in your data yet — keep wearing the strap and they’ll '
      'surface here.';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final real = [
      for (final finding in findings)
        if (!isTrivialFinding(finding)) finding,
    ].take(maxShown).toList();
    if (real.isEmpty) {
      return InstrumentModule(
        label: '',
        tag: null,
        minHeight: 0,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              nothingYet,
              style: HType.sans(colors.ink3, size: 13.5, height: 1.5),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (final finding in real)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FindingRow(finding: finding),
          ),
      ],
    );
  }
}

/// One pattern, its sentence and its arithmetic.
class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effect = (finding.effectSize ?? 0).abs();
    final samples = finding.nSamples ?? 0;
    return InstrumentModule(
      label: 'Pattern',
      tag: colors.accent,
      minHeight: 0,
      trailing: Text(
        strengthLabel(effect).toUpperCase(),
        style: HType.label(colors.accent, size: 8, tracking: 0.1),
      ),
      children: [
        Text(
          describeFinding(finding).headline,
          style: HType.serif(colors.ink, size: 16, height: 1.4),
        ),
        const SizedBox(height: 8),
        ModuleFoot('r ${effect.toStringAsFixed(2)} · $samples days of your data'),
      ],
    );
  }
}

/// The owner-facing name for a metric id. Legacy's `_metricFriendly` (1467).
///
/// An id with no entry has its underscores replaced, which is legacy's own
/// `m.replaceAll('_', ' ')`. That is a prettified id rather than a name, and
/// `shared/format/metric_names.dart` argues against the practice in general — it
/// is kept here because the sentence it lands in is legacy's and reads as prose,
/// where an id with underscores would not read at all.
String friendlyMetric(String? metric) {
  if (metric == null) {
    return '';
  }
  const names = <String, String>{
    'rhr_daily': 'resting HR',
    'hrv_sleep_avg': 'HRV',
    'hrv_rmssd_ms': 'HRV',
    'sleep_health_score_4dim': 'sleep health',
    'sleep_regularity_index': 'sleep regularity',
    'steps_total': 'steps',
    'total_calories': 'calories',
    'active_calories': 'active calories',
    'mvpa_min': 'active minutes',
    'spo2_overnight': 'blood oxygen',
    'sleep_score': 'sleep score',
    'respiratory_rate_sleep': 'breathing rate',
    'vo2max_estimate': 'VO₂max',
    'skin_temp_c': 'skin temp',
  };
  return names[metric] ?? metric.replaceAll('_', ' ');
}

/// How consistent a pattern is, in words. Legacy's four bands.
String strengthLabel(double absoluteEffect) {
  if (absoluteEffect >= 0.7) {
    return 'very consistent';
  }
  if (absoluteEffect >= 0.5) {
    return 'consistent';
  }
  if (absoluteEffect >= 0.4) {
    return 'fairly consistent';
  }
  return 'suggestive';
}

/// The sentence and the context line for one finding. Legacy's `_describeFinding`.
({String headline, String context}) describeFinding(Finding finding) {
  final a = friendlyMetric(finding.metricA);
  final b = friendlyMetric(finding.metricB);
  final effect = finding.effectSize ?? 0;
  final samples = finding.nSamples ?? 0;
  final lag = finding.lagDays ?? 0;
  final context =
      '${strengthLabel(effect.abs())} pattern · seen across $samples days';
  if (finding.metricB == null || b.isEmpty) {
    return (
      headline: finding.description ?? 'Pattern found in your data.',
      context: context,
    );
  }
  final direction = effect > 0 ? 'higher' : 'lower';
  final when = lag == 0
      ? ''
      : lag == 1
      ? ' the next day'
      : ' $lag days later';
  return (
    headline: 'When your $a is higher, your $b is usually $direction$when.',
    context: context,
  );
}

/// Whether a pair is definitionally derived rather than discovered.
///
/// Legacy's `_trivialFinding`, unchanged including the 0.97 cut-off.
bool isTrivialFinding(Finding finding) {
  final a = finding.metricA;
  final b = finding.metricB;
  if (a == null || b == null) {
    return false;
  }
  const activity = <String>{
    'steps_total',
    'distance_m_daily',
    'mvpa_min',
    'active_calories',
    'total_calories',
  };
  if (activity.contains(a) && activity.contains(b)) {
    return true;
  }
  for (final prefix in const ['sleep_dim_', 'sleep_health', 'sleep_regularity']) {
    if (a.startsWith(prefix) && b.startsWith(prefix)) {
      return true;
    }
  }
  if ((a.startsWith('sleep_dim') && b.contains('regularity')) ||
      (b.startsWith('sleep_dim') && a.contains('regularity'))) {
    return true;
  }
  final effect = finding.effectSize;
  // Near-perfect correlation is arithmetic, not a discovery.
  return effect != null && effect.abs() >= 0.97;
}
