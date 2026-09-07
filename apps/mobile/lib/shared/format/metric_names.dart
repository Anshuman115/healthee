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

/// The same name, cased for a heading rather than for a sentence.
///
/// [metricName] answers "what do I call this inside a sentence", so its table
/// is lower case — *"your overnight HRV rose"*. A screen title is the other
/// position and needs the same words with a capital, and deriving it here keeps
/// the ONE table: a second, title-cased map would be a second place for a
/// metric to be renamed and only one of them to get the memo.
///
/// Only the first character moves. `VO₂max` and `HRV` keep the capitals the
/// table already gives them, and an unknown id keeps its own shape — an id on
/// screen is legible as a gap, which is the argument this file already makes.
String metricTitle(String metric) {
  final name = metricName(metric);
  return name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}

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
  'sleep_score': 'sleep score',
  'sleep_regularity_index': 'sleep regularity',
  'sleep_dim_duration': 'sleep duration',
  'sleep_dim_efficiency': 'sleep efficiency',
  'sleep_dim_timing': 'sleep timing',
  'sleep_dim_regularity': 'sleep regularity',
  'asleep': 'time asleep',
  // The two the metric explorer found missing. Both are already words on the
  // Sleep screen (`need_panel.dart`), and an id printed on a tile is the exact
  // failure the library docstring above describes.
  'sleep_debt_min': 'sleep debt',
  'sleep_need_min': 'sleep need',

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

/// The owner-facing name for a VO₂max instrument.
///
/// The ids are `read/vo2max.py`'s three tiers. An unknown one keeps its id, so a
/// fourth instrument is visible rather than silently unnamed.
///
/// It lives here rather than beside one of the three cards that print it: the
/// v02 fitness panel, the pre-v02 Today card and the Activity card all name the
/// same instrument, and three copies of this switch is three chances for one of
/// them to call `hr_reserve` something else.
String methodLabel(String method) => switch (method) {
  'gps_graded' => 'a recorded session',
  'hr_reserve' => 'heart-rate reserve',
  'jurca_non_exercise' => 'the non-exercise model',
  _ => method,
};

/// The owner-facing name for a recovery factor id.
///
/// The keys are `recovery_score.factors`'s own — `hrv`, `rhr`, `rr`, `sleep` —
/// and they are identifiers, not words. `rr` under a bar on a health screen is
/// a log line where a name belongs, which is the same rule `note_names.dart`
/// holds for citations. An unknown key keeps its key, so a fifth factor is
/// visible rather than silently unnamed.
///
/// Here rather than beside one of the two cards that draw these bars: the v02
/// recovery panel and the pre-v02 recovery card name the same four things, and
/// two copies of this switch is two chances for one of them to call `rr`
/// something else.
String factorLabel(String name) => switch (name) {
  'hrv' => 'HRV',
  'rhr' => 'Resting HR',
  'rr' => 'Breathing',
  'sleep' => 'Sleep',
  _ => name,
};

/// The separator between two metrics in a correlation — `Caffeine ↔ sleep`.
///
/// The character is the prototype's own (`screens-overview.js`, the
/// relationship card). What is added is `\u{FE0E}`, VARIATION SELECTOR-15:
/// U+2194 carries **emoji presentation by default on Android**, so written bare
/// it rendered as a boxed colour glyph in the middle of a sentence. The selector
/// asks for the text form. Nothing about the design changed; only its rendering
/// was wrong.
///
/// Shared rather than inlined because a correlation is named on more than one
/// surface, and a second copy is a second chance to reach for `→` — which would
/// claim a direction the statistic does not have.
const String kPairArrow = '↔︎';
