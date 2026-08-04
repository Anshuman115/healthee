/// In-memory aggregate of everything fetched from the strap, keyed by metric.
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// strap_data.dart`, with one typing adaptation: the four loose daily-total
/// fields (`dailySteps`, `dailyDistanceM`, `dailyCalories`, `dailyTotalsDate`)
/// are one [DeviceDailyTotals] value, because four nullable fields that are
/// only ever meaningful together are four chances to read three of them.
///
/// Samples arrive chronologically — the fetch pages forward.
///
/// ## What this is not
///
/// It is not the 60-day store, and it is not a cache. It is the shape the
/// protocol layer hands back at the end of one sync. Persisting it is the next
/// package's job.
library;

import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/sleep_session.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/models/workout.dart';

/// Everything one sync produced, in memory.
class StrapData {
  /// Samples by metric name, chronological within each metric.
  final Map<String, List<StrapSample>> series = {};

  /// Sleep sessions, nights and naps.
  List<SleepSession> sleep = [];

  /// Workout summaries.
  List<Workout> workouts = [];

  /// When the last sync finished.
  DateTime? lastSync;

  /// Strap battery percent (standard BLE char `0x2A19`), read on connect.
  int? battery;

  /// The strap's own since-midnight counters. **Authoritative for steps** even
  /// when the per-minute stream is frozen — see [DeviceDailyTotals].
  DeviceDailyTotals? dailyTotals;

  /// Files [samples] into [series] under their own metric names.
  void ingest(List<StrapSample> samples) {
    for (final s in samples) {
      (series[s.metric] ??= <StrapSample>[]).add(s);
    }
  }

  /// True when nothing has been fetched.
  bool get isEmpty => series.isEmpty && sleep.isEmpty;

  /// Drops every sample, session and workout.
  void clear() {
    series.clear();
    sleep = [];
    workouts = [];
    lastSync = null;
  }

  /// The samples for [m], or an empty list.
  List<StrapSample> seriesOf(String m) => series[m] ?? const [];

  /// How many samples [m] has.
  int count(String m) => series[m]?.length ?? 0;

  /// The most recent value of [m], or null.
  double? latest(String m) {
    final s = series[m];
    return (s != null && s.isNotEmpty) ? s.last.value : null;
  }

  /// The median value of [m], or null.
  double? median(String m) {
    final s = series[m];
    if (s == null || s.isEmpty) return null;
    final v = s.map((e) => e.value).toList()..sort();
    final n = v.length;
    return n.isOdd ? v[n ~/ 2] : (v[n ~/ 2 - 1] + v[n ~/ 2]) / 2;
  }

  /// Latest minus median, as a crude z-less delta for the metric cards.
  double? delta(String m) {
    final l = latest(m);
    final md = median(m);
    return (l != null && md != null) ? l - md : null;
  }

  /// Downsampled (x = epoch ms, y = value) points for charts.
  List<(num, num)> points(String m, {int max = 400}) {
    final s = series[m];
    if (s == null || s.isEmpty) return const [];
    final step = (s.length / max).ceil().clamp(1, 1 << 30);
    final out = <(num, num)>[];
    for (var i = 0; i < s.length; i += step) {
      out.add((s[i].date.millisecondsSinceEpoch, s[i].value));
    }
    return out;
  }

  /// Bucket a metric into hourly averages (min/max/avg per absolute hour),
  /// chronological. For clean charts instead of thousands of raw points.
  List<({DateTime hour, double avg, double min, double max})> hourly(String m) {
    final s = series[m];
    if (s == null || s.isEmpty) return const [];
    final buckets = <int, List<double>>{};
    for (final x in s) {
      final h = x.date.millisecondsSinceEpoch ~/ 3600000;
      (buckets[h] ??= <double>[]).add(x.value);
    }
    final keys = buckets.keys.toList()..sort();
    return [
      for (final k in keys)
        (
          hour: DateTime.fromMillisecondsSinceEpoch(k * 3600000),
          avg: buckets[k]!.reduce((a, b) => a + b) / buckets[k]!.length,
          min: buckets[k]!.reduce((a, b) => a < b ? a : b),
          max: buckets[k]!.reduce((a, b) => a > b ? a : b),
        ),
    ];
  }

  /// 15-min step buckets for the most recent day (bucket 0..95, summed steps),
  /// matching the web today_step_buckets shape.
  List<({int bucket, int steps})> stepBuckets() {
    final s = series['steps'];
    if (s == null || s.isEmpty) return const [];
    final lastDate = s.last.date;
    final dayStart = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final buckets = <int, double>{};
    for (final x in s) {
      if (x.date.isBefore(dayStart)) continue;
      final b = (x.date.difference(dayStart).inMinutes ~/ 15).clamp(0, 95);
      buckets[b] = (buckets[b] ?? 0) + x.value;
    }
    final keys = buckets.keys.toList()..sort();
    return [for (final k in keys) (bucket: k, steps: buckets[k]!.round())];
  }

  /// The most recent sleep session.
  SleepSession? get lastNight => sleep.isEmpty
      ? null
      : (sleep.toList()
              ..sort((a, b) => a.sessionStart.compareTo(b.sessionStart)))
            .last;

  // ── daily / nightly aggregations for the history views ──
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// One value per local day = the last reading that day (for daily metrics
  /// like resting_hr / max_hr). Chronological.
  List<({DateTime day, double value})> dailyLast(String m) {
    final s = series[m];
    if (s == null || s.isEmpty) return const [];
    final map = <int, StrapSample>{};
    for (final x in s) {
      final k = _day(x.date).millisecondsSinceEpoch;
      final cur = map[k];
      if (cur == null || x.date.isAfter(cur.date)) map[k] = x;
    }
    final keys = map.keys.toList()..sort();
    return [
      for (final k in keys)
        (day: DateTime.fromMillisecondsSinceEpoch(k), value: map[k]!.value),
    ];
  }

  /// Daily summed totals (steps). Chronological.
  List<({DateTime day, double total})> dailyTotal(String m) {
    final s = series[m];
    if (s == null || s.isEmpty) return const [];
    final map = <int, double>{};
    for (final x in s) {
      final k = _day(x.date).millisecondsSinceEpoch;
      map[k] = (map[k] ?? 0) + x.value;
    }
    final keys = map.keys.toList()..sort();
    return [
      for (final k in keys)
        (day: DateTime.fromMillisecondsSinceEpoch(k), total: map[k]!),
    ];
  }

  /// Per-night mean of a metric over each sleep window (HRV/SpO₂ trends).
  List<({DateTime day, double value})> nightlyMean(String m) {
    final out = <({DateTime day, double value})>[];
    for (final n in sleep) {
      if (n.stages.isEmpty) continue;
      final start = n.stages.first.start;
      final end = n.stages.last.end;
      final vals = seriesOf(m)
          .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
          .map((s) => s.value)
          .toList();
      if (vals.isEmpty) continue;
      out.add((
        day: _day(n.sessionStart),
        value: vals.reduce((a, b) => a + b) / vals.length,
      ));
    }
    out.sort((a, b) => a.day.compareTo(b.day));
    return out;
  }

  /// Sleep sessions, newest first.
  List<SleepSession> get sleepByNight =>
      sleep.toList()..sort((a, b) => b.sessionStart.compareTo(a.sessionStart));
}
