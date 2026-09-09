/// What a finding SAYS — its sentence, its foot line and its strength word.
///
/// Split out of `insights_section.dart` at the 400-line gate (Standards section
/// 1), along the seam the file already had: these are pure functions over a
/// `Finding`, with no widget among them, and the honesty arguments they carry
/// are about wording rather than layout.
library;

import 'package:healthee/data/models/finding.dart';

/// The foot line: the effect under **its own** instrument's name, and the window.
///
/// Legacy hard-coded the letter `r` here, and this file copied it. `effect_metric`
/// has been on the wire since `read/findings.py` was written, is parsed by
/// `Finding.effectMetric`, and was ignored — so a Spearman `rho` was drawn under
/// the symbol for Pearson's *r*, and a Mann-Whitney rank-biserial statistic got the
/// same letter for something else again. `finding.dart` states the rule on the
/// field itself: *"WHICH statistic [effectSize] is … without it a number between
/// −1 and 1 could be read as three different things."*
///
/// **The letter is withheld when the server did not send one**, the way `estimate`
/// and `method` are paired on the VO₂max card: a bare number is a number we cannot
/// name, and naming it wrong is worse than not naming it.
String findingFoot(Finding finding) {
  final effect = (finding.effectSize ?? 0).abs().toStringAsFixed(2);
  final samples = finding.nSamples ?? 0;
  final metric = finding.effectMetric;
  final figure = metric == null ? effect : '$metric $effect';
  return '$figure · $samples days of your data';
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
///
/// ## The one-metric branch, and what it may NOT fall back to
///
/// `metricB` is null for every `event_effect` and `personal_cutoff` finding, and
/// this branch used to return `finding.description` — the server's
/// `description_raw`, whose own docstring (`data/models/finding.dart`) says *"do
/// not render it"* and records that **it reached the home screen verbatim once**.
/// It reached it again. For an event finding the string an owner would have read
/// is `analytics/correlations.py`'s
///
/// > `caffeine days vs others (same day, sleep_health_score_4dim): rank-biserial
/// > r=-0.42 (p=0.031, n_event=12, n_other=45)`
///
/// The structured field that answers the same question is [Finding.eventKind],
/// which this file already parsed and never used, and `shared/findings_section.dart`
/// has composed a sentence from it since the first rewrite. Both composers now do,
/// and `test/features/findings_wording_test.dart` names **both** — a guard that
/// covers one of two composers is half a guard, which is exactly how this shipped.
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
      headline: _oneMetricHeadline(a, finding.eventKind),
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

/// The headline for a finding that carries ONE metric rather than a pair.
///
/// Built from the structured fields, never from `description_raw`. With an event
/// kind it is the same sentence `shared/findings_section.dart` composes; without
/// one there is nothing to name the comparison, so the sentence says only what is
/// known. The last fallback — no metric at all — claims nothing whatsoever.
String _oneMetricHeadline(String metric, String? eventKind) {
  if (metric.isEmpty) {
    return 'Pattern found in your data.';
  }
  return eventKind == null
      ? 'Your $metric, on the days it was recorded.'
      : 'Your $metric on $eventKind days, against your other days.';
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
  for (final prefix in const [
    'sleep_dim_',
    'sleep_health',
    'sleep_regularity',
  ]) {
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
