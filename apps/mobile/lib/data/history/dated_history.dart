/// Every dated series the app can draw, read in ONE request.
///
/// ## Why one request and not one per chart
///
/// `/api/history` served a single metric per call. The prototype's past-day
/// screens draw five to nine dated panels each, so Today alone would have opened
/// fourteen connections to render one screen — the N+1 shape Standards section 1
/// bans on a read path, moved from the database onto the radio. The server grew
/// `?metrics=a,b,c` for exactly this (`BACKEND_GAPS_FROM_UI.md` C1), and this is
/// its client.
///
/// ## It asks for everything the app lists, and that is deliberate
///
/// Not the union of what the six screens happen to draw. Two reasons, and both
/// are about the cache rather than the wire:
///
///   * **one entry, shared.** Six screens and two toggles of the date control
///     hit the same provider with the same argument, so the fortnight of charts
///     behind a past day is fetched once per session rather than once per visit;
///   * **no per-screen key.** A provider keyed by a metric list is keyed by a
///     `List`, whose equality is identity — a screen that built its list inline
///     would miss the cache on every rebuild and refetch forever.
///
/// The whole registry is twenty-five series, which the server answers in four
/// statements. A per-screen subset would be a smaller payload and a worse
/// program.
///
/// ## `keepAlive`, and what invalidates it
///
/// Kept for the session for the reason above: the reader steps back and forth
/// across the date control and must not pay for a round trip each way.
/// Pull-to-refresh invalidates it alongside `/api/today`, so a sync that lands
/// new days is what makes these charts move — not the passage of time.
///
/// ## A day with no reading is absent from the answer, and stays absent here
///
/// The server sends only the days it has. Nothing in this file pads, fills or
/// carries a value forward; `HistoryWindow` lays the sparse series back onto the
/// calendar with `null` in the holes, and the chart breaks its line there. A
/// value invented for a day nobody measured would be the one failure this whole
/// product is built to avoid.
library;

import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dated_history.g.dart';

/// How far back the batched read asks for.
///
/// The date control reaches [localHorizonDays] back (`view_date.dart`) and a
/// dated panel draws a fortnight ending on the day chosen, so the oldest chart
/// the owner can ask for starts 73 days ago. 90 is that with room, and it is
/// the server's own default window — a number this app does not need a second
/// opinion about.
const int kDatedHistoryDays = 90;

/// Every dated series the app lists, keyed by the server's canonical metric id.
@immutable
class DatedHistory {
  /// Built by [parseDatedHistory]. [days] is the window the SERVER answered for,
  /// which is not always the one that was asked for — it clamps.
  const DatedHistory({required this.days, required this.series});

  /// The window the server actually answered for, in days.
  final int days;

  /// The answered series by canonical metric id, oldest first within each.
  ///
  /// Prefer [operator []] and [covers]: the map cannot express the difference
  /// between "no readings" and "not asked about", and those two must never
  /// render the same way.
  final Map<String, List<TrendPoint>> series;

  /// The observations for [metric], oldest first. Empty when there are none.
  ///
  /// Empty is also what an unasked-for metric returns, which is why [covers]
  /// exists: a caller that cannot tell "you have no readings" from "nobody
  /// asked" would render the second as the first.
  List<TrendPoint> operator [](String metric) =>
      series[metric] ?? const <TrendPoint>[];

  /// Whether this read asked about [metric] at all.
  bool covers(String metric) => series.containsKey(metric);

  /// The metrics this read carries, in the order the server listed them.
  Iterable<String> get metrics => series.keys;
}

/// Every dated series, in one request. See the library docstring.
@Riverpod(keepAlive: true)
Future<DatedHistory> datedHistory(Ref ref) async {
  final dio = ref.watch(apiClientProvider);
  final session = await CacheSession.capture(ref.watch(credentialsProvider));
  final response = await dio.get<Map<String, Object?>>(
    '/api/history',
    queryParameters: <String, Object?>{
      'metrics': HistoryMetric.values.map((m) => m.id).join(','),
      'days': kDatedHistoryDays,
    },
    options: session.options(),
  );
  await session.ensureCurrent();
  return parseDatedHistory(response.data!);
}

/// Parses the batched payload, or throws rather than drawing a partial answer.
///
/// The same rules `parseHistory` applies to one series, applied to each: a
/// non-finite value, a day that is not the date it claims to be, and a series
/// that does not ascend are all rejected. Silently dropping a bad point would
/// close a gap in a chart with a shrug.
DatedHistory parseDatedHistory(Map<String, Object?> json) {
  final days = json['days'];
  if (days is! num || days < 1) {
    throw const FormatException('History window must be a positive day count');
  }
  final series = json['series'];
  if (series is! Map<String, Object?>) {
    throw const FormatException('Batched history must be keyed by metric');
  }
  return DatedHistory(
    days: days.toInt(),
    series: <String, List<TrendPoint>>{
      for (final entry in series.entries)
        entry.key: parseSeries(entry.value, entry.key),
    },
  );
}

/// One metric's dated points, validated. Shared with `history_repository.dart`
/// so the single-metric screen and the panels cannot disagree about a reading.
List<TrendPoint> parseSeries(Object? raw, String metric) {
  if (raw is! List<Object?>) {
    throw FormatException('History series for $metric is not a list');
  }
  final points = <TrendPoint>[];
  for (final item in raw) {
    if (item is! Map<String, Object?>) {
      throw FormatException('History observation for $metric is not an object');
    }
    final day = item['day'];
    final value = item['value'];
    if (day is! String || value is! num) {
      throw FormatException('Invalid history observation for $metric');
    }
    final date = DateTime.tryParse(day);
    if (!value.toDouble().isFinite ||
        date == null ||
        date.toIso8601String().substring(0, 10) != day) {
      throw FormatException('Invalid history observation for $metric');
    }
    if (points.isNotEmpty && points.last.date.compareTo(day) >= 0) {
      throw FormatException('History dates must increase for $metric');
    }
    points.add(TrendPoint(date: day, value: value.toDouble()));
  }
  return points;
}
