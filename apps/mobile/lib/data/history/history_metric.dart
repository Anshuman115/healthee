/// Daily metrics stored by the server, with their canonical units.
/// The history endpoint also exposes daily weigh-ins and MVPA flag components.
enum HistoryMetric {
  hrv('hrv_sleep_avg', 'ms'),
  restingHr('rhr_daily', 'bpm'),
  oxygen('spo2_overnight', '%'),
  breathing('respiratory_rate_sleep', 'breaths/min'),
  sleepHealth('sleep_health_score_4dim', '/4'),
  sleepRegularity('sleep_regularity_index', '/100'),
  steps('steps_total', 'steps'),
  activeMinutes('mvpa_min', 'min'),
  activeEnergy('active_calories', 'kcal'),
  totalEnergy('total_calories', 'kcal'),
  cardioLoad('cardio_load', 'TRIMP'),
  recovery('recovery_score', '/100'),
  fitness('vo2max_estimate', 'ml/kg/min'),
  weight('weight_kg', 'kg'),
  sleepDebt('sleep_debt_min', 'min'),
  sleepNeed('sleep_need_min', 'min'),
  distance('distance_m_daily', 'm'),
  moderate('moderate_min', 'min'),
  vigorous('vigorous_min', 'min'),
  basalEnergy('basal_calories', 'kcal');

  const HistoryMetric(this.id, this.unit);
  final String id;
  final String unit;
}

/// The explainer key for a canonical metric id — [historyMetricFor] inverted.
///
/// `kMetricInfo` is keyed by the explainer's own vocabulary (`hrv`, `vo2max`,
/// `resp`) for some entries and by the canonical id (`rhr_daily`,
/// `steps_total`) for others, so a screen that has an id and wants the
/// explainer has to search the same alias table this file already owns rather
/// than keeping a second one — two tables is two chances for one of them to map
/// `spo2` somewhere else.
///
/// Falls back to [metric] itself, which is right for every entry keyed by its
/// id. An id with no explainer either way resolves to a key the map does not
/// hold, and `MetricInfoDot` already draws nothing for that unless the card
/// carries provenance of its own.
String explainerKeyFor(String metric) {
  for (final entry in _aliases.entries) {
    if (entry.value == metric) {
      return entry.key;
    }
  }
  return metric;
}

/// Explainer vocabulary maps to canonical server metrics without v1 aliases.
String? historyMetricFor(String key) {
  final id = _aliases[key] ?? key;
  return HistoryMetric.values.any((m) => m.id == id) ? id : null;
}

/// The one alias table, read in both directions.
const Map<String, String> _aliases = <String, String>{
  'hrv': 'hrv_sleep_avg',
  'resp': 'respiratory_rate_sleep',
  'vo2max': 'vo2max_estimate',
  'sleep_health': 'sleep_health_score_4dim',
  'sleep_consistency': 'sleep_regularity_index',
  'sleep_debt': 'sleep_debt_min',
  'energy': 'total_calories',
  'mvpa': 'mvpa_min',
  'spo2': 'spo2_overnight',
};
