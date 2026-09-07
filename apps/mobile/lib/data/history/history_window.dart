/// The window a metric's history is drawn over: one slot per calendar day.
///
/// ## The bug this type exists to prevent
///
/// `/api/history` returns only the days it has. Handed straight to a chart that
/// positions samples by INDEX, a fortnight with two missing nights draws twelve
/// evenly-spaced points and joins all of them: the gap disappears, and the two
/// days either side of it are drawn as if they were consecutive. The line then
/// interpolates across days nothing was measured on, which is the fabricated
/// -data failure `chart_curve.dart` was written about.
///
/// So the sparse series is expanded to one slot per day between its own first
/// and last date, with `null` where the store holds nothing. `V02LineChart`
/// splits on nulls (`seriesRuns`), so **the hole is drawn as a hole** and the
/// x-axis is a calendar rather than a sample counter.
///
/// ## A day the store does not hold is absent, never zero
///
/// The empty slot is `null` and never `0`. Zero steps is a measurement — a day
/// spent in bed — and a day the strap was not worn is not that. `history_test`
/// pins the distinction on the parse side; this file is the drawing side of the
/// same rule.
///
/// ## The end of the window follows the reader
///
/// The prototype's history views stop at the day the reader has selected
/// (`history-data.js::H.historySeries` filters `p.date <= viewDate`), which is
/// what makes a past day a past day rather than today's chart under an old
/// heading. [HistoryWindow.through] is that filter, and it is the only place a
/// date bound is applied.
///
/// ## Two ways to end on a day, and they answer different questions
///
/// [HistoryWindow.through] keeps every reading up to a day and lets the window
/// end wherever the last one did — right for the metric screen, whose caption is
/// the range of what was measured.
///
/// [HistoryWindow.endingOn] fixes both edges on the calendar: exactly `days`
/// slots, the last of them the chosen day, whatever was measured. It is what a
/// dated panel needs, and the difference is visible whenever the last reading is
/// older than the selection. The prototype takes the last N **observations**
/// (`slice(-limit)` over a filtered array), which on an index-positioned chart
/// pulls older readings forward until the fortnight looks complete. This chart
/// is calendar-positioned, so the same trick would silently redate them. A
/// window that ends on the selected day with trailing nulls says the true thing:
/// nothing was measured since.
///
/// ## It lives in `data/`, not in a feature
///
/// Six screens draw dated panels from it and `shared/v02/dated_history.dart`
/// builds them, so a copy in `features/history/` would be five features reaching
/// sideways into a sixth — which Standards section 1 forbids for the reason this
/// type exists to serve: one definition of where a gap is.
library;

import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/format/date_labels.dart';

/// A metric's observations laid out on the calendar they were measured on.
class HistoryWindow {
  /// Builds the window from [points], which must be dated and ascending —
  /// `parseHistory` has already rejected anything else.
  factory HistoryWindow(List<TrendPoint> points) {
    if (points.isEmpty) {
      return const HistoryWindow._(
        <double?>[],
        <String>[],
        <TrendPoint>[],
      );
    }
    final first = _day(points.first.date);
    final last = _day(points.last.date);
    final span = last.difference(first).inDays;
    final byDay = <String, double>{
      for (final point in points) point.date: point.value,
    };
    final values = <double?>[];
    final days = <String>[];
    for (var i = 0; i <= span; i++) {
      final day = _iso(first.add(Duration(days: i)));
      days.add(day);
      values.add(byDay[day]);
    }
    return HistoryWindow._(values, days, points);
  }

  /// The [days] calendar days ending on [day], filled from [points].
  ///
  /// Both edges are the calendar's, so the chart ends on the day in the header
  /// even when the last reading is older — the empty slots between are drawn as
  /// the holes they are. [days] below one is one: a window of no days is not a
  /// shorter question, it is a malformed one, and an empty chart under a figure
  /// would say nothing about why.
  factory HistoryWindow.endingOn(
    List<TrendPoint> points,
    String day,
    int days,
  ) {
    final span = days < 1 ? 1 : days;
    final last = _day(day);
    final first = last.subtract(Duration(days: span - 1));
    final firstIso = _iso(first);
    final byDay = <String, double>{
      for (final point in points)
        if (point.date.compareTo(firstIso) >= 0 &&
            point.date.compareTo(day) <= 0)
          point.date: point.value,
    };
    final values = <double?>[];
    final calendar = <String>[];
    final observed = <TrendPoint>[];
    for (var i = 0; i < span; i++) {
      final iso = _iso(first.add(Duration(days: i)));
      calendar.add(iso);
      final value = byDay[iso];
      values.add(value);
      if (value != null) {
        observed.add(TrendPoint(date: iso, value: value));
      }
    }
    return HistoryWindow._(values, calendar, observed);
  }

  const HistoryWindow._(this.values, this.days, this.observed);

  /// One slot per calendar day, oldest first. `null` is a day with no reading.
  final List<double?> values;

  /// The `YYYY-MM-DD` of each slot in [values], same length.
  final List<String> days;

  /// The measured observations only, in the order the server sent them.
  final List<TrendPoint> observed;

  /// Whether the store answered with nothing at all for this metric and period.
  bool get isEmpty => observed.isEmpty;

  /// `18 Jul`, `31 Jul` — the two edge captions under a chart.
  ///
  /// Empty when there is nothing to caption, so a chart that drew nothing does
  /// not gain a pair of dates implying it did.
  List<String> get captions => isEmpty
      ? const <String>[]
      : <String>[shortDate(days.first), shortDate(days.last)];

  /// One label per slot, for the chart's readout under the finger.
  List<String> get sampleLabels =>
      <String>[for (final day in days) shortDate(day)];

  /// This window cut off after [day], the way the prototype's history views cut
  /// theirs off at the selected date.
  ///
  /// A window whose observations all fall after [day] comes back empty rather
  /// than showing the nearest ones: "nothing on or before this day" is the
  /// honest answer, and the panel's own words say so.
  HistoryWindow through(String day) => HistoryWindow(<TrendPoint>[
    for (final point in observed)
      if (point.date.compareTo(day) <= 0) point,
  ]);

  /// The reading on [day], or null when the store holds none for it.
  double? on(String day) {
    for (final point in observed) {
      if (point.date == day) {
        return point.value;
      }
    }
    return null;
  }

  static DateTime _day(String iso) => DateTime.parse('${iso}T00:00:00Z');

  static String _iso(DateTime day) => day.toIso8601String().substring(0, 10);
}
