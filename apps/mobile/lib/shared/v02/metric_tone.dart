/// Which v02 family a metric belongs to, and which glyph that family wears.
///
/// The prototype keys this off `H.metricDefinitions[id].tone` and the block at
/// the foot of `panels.js`:
///
/// ```js
/// {hr:'heart', rhr:'heart', hrv:'fitness', stress:'stress', spo2:'oxygen',
///  breathing:'oxygen', steps:'movement', energy:'movement', weight:'fitness',
///  load:'heart'}
/// ```
///
/// ## This is an IDENTITY, exactly like `hueFor`, and never a verdict
///
/// `shared/format/metric_polarity.dart` is the other table and it is the
/// opposite thing: it says which *direction* is better and it is the only thing
/// that licenses `fav`/`unf`. This one takes an id and nothing else — there is
/// no reading, no delta and no window in the signature — so a family that
/// depended on how the owner did today is not something a caller can express.
/// `instrument_hues.dart` makes the same argument for the pre-v02 hues and this
/// is the v02 restatement of it.
///
/// **An unknown metric resolves to [Tone.fitness]**, which is `richer.css`
/// `:root` — content outside any `data-tone` is the accent. That is the
/// prototype's own default rather than a colour picked here, and it is not a
/// claim: green is where the cascade starts, not a verdict about the number.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';

/// The family [metric] belongs to. Never depends on its value.
Tone toneForMetric(String metric) => _tones[metric] ?? Tone.fitness;

/// The glyph the prototype draws beside a panel of [tone].
///
/// `components.js`'s icon set, mapped to the Material names this app already
/// uses for the same families on Today — one glyph per family, so a metric
/// cannot pick up an icon that disagrees with its colour.
IconData iconForTone(Tone tone) => switch (tone) {
  Tone.sleep => Icons.bedtime_outlined,
  Tone.heart || Tone.load => Icons.favorite_outline,
  Tone.movement || Tone.activity => Icons.directions_walk,
  Tone.oxygen => Icons.water_drop_outlined,
  Tone.stress => Icons.wb_sunny_outlined,
  Tone.fitness || Tone.recovery => Icons.monitor_heart_outlined,
};

/// The server's canonical ids, in the prototype's families.
///
/// Keyed by the ids `sparklines` and `metrics` actually carry, so a metric that
/// gains a surface without gaining a family is visible here as an absence rather
/// than as a panel that quietly came out green.
const Map<String, Tone> _tones = <String, Tone>{
  'hrv_sleep_avg': Tone.fitness,
  'hrv_rmssd_ms': Tone.fitness,
  'rhr_daily': Tone.heart,
  'cardio_load': Tone.load,
  'stress': Tone.stress,
  'skin_temp_c': Tone.stress,
  'spo2_overnight': Tone.oxygen,
  'spo2_overnight_min': Tone.oxygen,
  'respiratory_rate_sleep': Tone.oxygen,
  'steps_total': Tone.movement,
  'distance_m_daily': Tone.movement,
  'active_calories': Tone.movement,
  'basal_calories': Tone.movement,
  'total_calories': Tone.movement,
  'mvpa_min': Tone.movement,
  'sleep': Tone.sleep,
  'sleep_score': Tone.sleep,
  'sleep_duration': Tone.sleep,
  'sleep_regularity_index': Tone.sleep,
  'sleep_health_score_4dim': Tone.sleep,
  'vo2max_estimate': Tone.fitness,
  'biological_age': Tone.fitness,
  'recovery_score': Tone.fitness,
  'weight_kg': Tone.fitness,
};
