/// How a named metric's series must be drawn — its join, and its resolution.
///
/// `chart_curve.dart` argues *why* a total or an extremum may not be splined:
/// a curve between two samples is a claim about values that were never
/// measured, and Fritsch–Carlson only guarantees the drawn line stays inside
/// the sample range — it does not make Tuesday's step total ease into
/// Wednesday's. That argument is per **metric**, not per chart, so the answer
/// belongs in one table keyed by the server's canonical ids rather than at each
/// call site that happens to plot one.
///
/// ## Why this is not a field on `HistoryMetric`
///
/// `data/history/history_metric.dart` is the data layer's table of what the
/// server serves. A `SeriesCurve` is a painting decision, and putting one on
/// the enum would make the data layer import the chart layer to describe a
/// wire format. The two tables are keyed by the same ids, so a metric that
/// gains a series without gaining a curve is visible here as an absence rather
/// than as a chart that quietly came out splined.
///
/// **An unknown metric gets [SeriesCurve.straight]**, which is the conservative
/// answer and not a guess: a straight join asserts only that two measured
/// points exist, where a spline asserts a path between them. Defaulting the
/// other way would mean every metric this table has not heard of is drawn with
/// a claim nobody made.
library;

import 'package:healthee/shared/charts/v02/chart_curve.dart';

/// How [metric]'s samples are joined. Never depends on the values.
SeriesCurve seriesCurveFor(String metric) =>
    _continuous.contains(metric) ? SeriesCurve.monotone : SeriesCurve.straight;

/// Decimal places [metric]'s readings carry on a chart's readout.
///
/// Deliberately coarser than `decimalLabel`, which switches on magnitude: a
/// chart's readout must not gain a decimal halfway along a series because one
/// sample crossed 100. An unknown metric gets 0 — a tenth this app cannot show
/// the provenance of is a tenth it should not print.
int decimalsFor(String metric) => _tenths.contains(metric) ? 1 : 0;

/// The signals a body actually varies through, sampled densely enough that the
/// space between two samples is a real path rather than a summary boundary.
const Set<String> _continuous = <String>{
  'hrv_sleep_avg',
  'hrv_rmssd_ms',
  'rhr_daily',
  'spo2_overnight',
  'respiratory_rate_sleep',
  'skin_temp_c',
  'weight_kg',
  'stress',
};

/// The metrics whose readings are meaningful to a tenth.
const Set<String> _tenths = <String>{
  'hrv_sleep_avg',
  'hrv_rmssd_ms',
  'vo2max_estimate',
  'weight_kg',
  'respiratory_rate_sleep',
  'skin_temp_c',
  'efficiency_pct',
};
