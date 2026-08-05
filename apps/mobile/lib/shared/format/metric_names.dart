/// The owner-facing name for a canonical metric id.
///
/// ## Why the app has to own this table at all
///
/// `/api/today` labels the metrics it puts on a **card** (`metrics[].label`, from
/// the server's `read/meta.py::METRIC_META`) and does not label the ones it puts
/// in a **finding**. A finding arrives as `metric_a: "hrv_sleep_avg"`,
/// `metric_b: "recovery_score"` — ids, because that is what the correlation
/// search ran over. Rendering them raw is how a screen ends up saying
/// `Spearman(hrv_sleep_avg, recovery_score) = +0.72`, which is a log line.
///
/// So the ids get names here. The names are the ones the rest of the app already
/// uses for the same quantity — the sleep screen's "Overnight HRV" and this
/// table's must be the same words, or one metric has two names.
///
/// ## An unknown id keeps its id, and that is deliberate
///
/// [metricName] returns the id unchanged when it does not recognise it. The
/// alternative — prettifying `foo_bar_baz` into "Foo bar baz" — invents an
/// owner-facing name for something nobody named, and it hides the fact that the
/// server grew a metric this app has never heard of. An id on screen is ugly and
/// legible as a gap; a manufactured phrase is neither.
library;

/// The plain-English name for a metric id, or the id when it has none.
///
/// The keys are the server's canonical v2 names — `analytics/metrics.py`'s
/// `METRIC_FILTERS` is the registry the correlation search draws its series from,
/// and every id it can emit is either here or deliberately absent.
String metricName(String metric) => _names[metric] ?? metric;

/// True when [metric] has a name here — i.e. the app can put it in a sentence.
///
/// A finding whose metrics are both unnamed still renders; it just falls back to
/// naming them by id, which reads as unfinished because it is.
bool hasMetricName(String metric) => _names.containsKey(metric);

const Map<String, String> _names = <String, String>{
  // Overnight instruments.
  'rhr_daily': 'resting heart rate',
  'hrv_sleep_avg': 'overnight HRV',
  'spo2_overnight': 'overnight blood oxygen',
  'spo2_overnight_min': 'lowest blood oxygen overnight',
  'respiratory_rate_sleep': 'overnight breathing rate',
  'skin_temp_c': 'skin temperature',

  // Sleep.
  'tst_min': 'time asleep',
  'tib_min': 'time in bed',
  'efficiency_pct': 'sleep efficiency',
  'sleep_health_score_4dim': 'sleep health',
  'sleep_regularity_index': 'sleep regularity',
  'sleep_dim_duration': 'sleep duration',
  'sleep_dim_efficiency': 'sleep efficiency',
  'sleep_dim_timing': 'sleep timing',
  'sleep_dim_regularity': 'sleep regularity',
  'asleep': 'time asleep',

  // Movement and energy.
  'steps_total': 'steps',
  'distance_m_daily': 'distance',
  'distance_m': 'distance',
  'mvpa_min': 'active minutes',
  'moderate_min': 'moderate minutes',
  'vigorous_min': 'vigorous minutes',
  'cardio_load': 'cardio load',
  'active_calories': 'active calories',
  'total_calories': 'total calories',
  'basal_calories': 'resting calories',

  // Judgements and the body.
  'recovery_score': 'recovery',
  'vo2max_estimate': 'VO₂max',
  'weight_kg': 'weight',
  'caffeine': 'caffeine',
  'alcohol': 'alcohol',
};
