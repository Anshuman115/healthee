/// The six-module grid that opens Today — legacy's instrument grid, retinted.
///
/// **Ported from** `design_reference/project/hh/screen_today.jsx`'s module grid:
/// Sleep · Resting HR · HRV · Steps · Energy · Resp/SpO₂, two to a row, each a
/// label, a tag dot, a 27 px figure with a small unit, a chart, and one all-caps
/// foot. This is the density the screen was missing, and it is the whole reason
/// the rebuild exists.
///
/// ## Every cell is a DOOR, and that is load-bearing
///
/// Legacy's cells carry `onClick={() => onOpen('sleep' | 'heart' | 'activity' |
/// 'respiratory')}` — the grid is an index and the detail lives behind it. Ours
/// do the same, and where each one leads is the other half of a bargain
/// `grid_module.dart` strikes: a 118 px cell never carries a refusal's reason and
/// remedy, because the screen it opens renders the full `WithheldCard`.
///
/// ```text
///   Sleep         → Sleep      SleepNightCard · sleep health · debt · the week
///   Resting HR    → Sleep      the overnight instruments live with the night
///   HRV           → Sleep
///   Steps         → Activity   StepsCard · cardio load · active minutes
///   Energy        → Activity
///   Resp / SpO₂   → Sleep      BloodOxygenCard
/// ```
///
/// The doors arrive as a required argument rather than being read from a table
/// here, so a cell cannot outlive its destination: deleting the Sleep screen
/// stops this file compiling rather than shipping a tap into nothing.
///
/// ## Where each figure comes from, and why it is never blended
///
/// Two sources reach this screen and a cell reads exactly one of them, preferring
/// the server's copy when it has one and falling back to the strap's whole
/// [Reading] — reason included — when it does not. It never averages them.
///
/// **When it falls back, the cell says so in its label.** `Resting HR` becomes
/// `Resting HR · strap` and `HRV` becomes `HRV · strap`, because the two are not
/// the same measurement: the server's `rhr_daily` is the minimum of 5-minute mean
/// heart rate inside the sleep window, and the strap's `resting_hr` is the
/// firmware's own estimate, latest of the day and usually taken awake. Five to
/// ten bpm apart is ordinary. CLAUDE.md allows one canonical definition per
/// metric; a cell that silently swapped instrument under one label would be a
/// second one, which is exactly the failure the owner caught between the
/// baselines strip and the strap strip. `diagnostics_screen.dart` carries the
/// full rule.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_metric.dart';
import 'package:healthee/data/device/device_night.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/data/models/metric_card.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/widgets/grid_module.dart';
import 'package:healthee/shared/charts/h_hypnogram.dart';
import 'package:healthee/shared/format/number_labels.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Today's six instrument modules.
class MetricGrid extends StatelessWidget {
  /// [reveals] must be the screen's registry, not one built here.
  const MetricGrid({
    required this.day,
    required this.reveals,
    required this.onOpen,
    this.snapshot,
    super.key,
  });

  /// What the strap measured, and its refusals.
  final DeviceDay day;

  /// Where "this cell has already animated" is remembered.
  final RevealRegistry reveals;

  /// Opens the screen a cell indexes. Required — see the library docstring.
  final void Function(String route) onOpen;

  /// What the server made of it, or null when it has not answered.
  final TodaySnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    // Every cell asks `tagFor` rather than naming a field, so the assignment of
    // metric to family lives in ONE table. A grid that hard-coded `hues.heart`
    // for resting HR would be a second copy of that decision, free to disagree
    // with the screen the cell opens.
    final hues = context.hues;
    return ModuleGrid(
      modules: [
        _sleep(hues),
        _restingHeartRate(hues),
        _hrv(hues),
        _steps(hues),
        _energy(hues),
        _breathing(hues),
      ],
    );
  }

  // ── the six slots ─────────────────────────────────────────────────────────

  Widget _sleep(MetricHues hues) {
    // The server's copy when it has one — it is what every derived sleep
    // judgement further down was computed from — and the strap's own night,
    // reason included, when it does not. Never merged.
    final server = _serverNight;
    final night = server.hasValue ? server : _deviceNight;
    return GridModule(
      label: 'Sleep',
      tag: hues.tagFor('sleep_duration'),
      onOpen: () => onOpen(TodayDoors.overnight),
      reading: night.map((n) => n.minutes.toDouble()),
      format: (minutes) => clockDuration(minutes.round()),
      unit: 'hrs',
      reveals: reveals,
      revealId: 'today.grid.sleep',
      chart: (context, t) => HHypnogram(
        night.valueOrNull?.spans ?? const <SleepStageSpan>[],
        progress: t,
        height: 28,
      ),
      foot: switch (night.valueOrNull) {
        final _NightShape shape =>
          'deep ${shape.deepMin}m · rem ${shape.remMin}m',
        _ => null,
      },
    );
  }

  Widget _restingHeartRate(MetricHues hues) {
    final card = _card('rhr_daily');
    return GridModule(
      // The label names the instrument when it is not the canonical one. See the
      // library docstring: these two numbers are five to ten bpm apart by
      // construction, and one label over both is the lie.
      label: card == null ? 'Resting HR · strap' : 'Resting HR',
      tag: hues.tagFor('rhr_daily'),
      onOpen: () => onOpen(TodayDoors.overnight),
      reading: card?.reading ?? _stream('resting_hr').reading,
      format: (value) => value.round().toString(),
      unit: 'bpm',
      spark: _spark('rhr_daily'),
      reveals: reveals,
      revealId: 'today.grid.rhr',
      foot: card == null
          ? _strapFoot('resting_hr')
          : _medianFoot(card, digits: 0),
    );
  }

  Widget _hrv(MetricHues hues) {
    // The server's overnight RMSSD is not wrapped in an honesty envelope — it is
    // an extra on `last_sleep`, present or absent — so its absence has no reason
    // to show. The strap's reading has one, so that is what a missing night
    // falls through to rather than a refusal this file would have to word.
    final overnight = snapshot?.overnightVitals?.hrvRmssdMs;
    final stream = _stream('hrv');
    return GridModule(
      label: overnight == null ? 'HRV · strap' : 'HRV',
      tag: hues.tagFor('hrv'),
      onOpen: () => onOpen(TodayDoors.overnight),
      reading: overnight == null ? stream.reading : Present<double>(overnight),
      format: (value) => value.round().toString(),
      unit: 'ms',
      spark: _spark('hrv_sleep_avg'),
      reveals: reveals,
      revealId: 'today.grid.hrv',
      foot: overnight == null ? _strapFoot('hrv') : 'overnight rmssd',
    );
  }

  Widget _steps(MetricHues hues) {
    // The strap's own since-midnight counter (#121), never the server's copy and
    // never a sum of the per-minute stream. `steps_card.dart` has the argument;
    // this cell shows the same number that card does, from the same field.
    return GridModule(
      label: 'Steps',
      tag: hues.tagFor('steps_total'),
      onOpen: () => onOpen(TodayDoors.daytime),
      reading: day.steps.map((steps) => steps.toDouble()),
      format: (steps) => groupedInt(steps.round()),
      spark: _spark('steps_total'),
      reveals: reveals,
      revealId: 'today.grid.steps',
      foot: _stepsFoot(),
    );
  }

  Widget _energy(MetricHues hues) {
    final card = _card('active_calories');
    final total = _card('total_calories')?.reading.valueOrNull;
    return GridModule(
      label: 'Energy',
      tag: hues.tagFor('active_calories'),
      onOpen: () => onOpen(TodayDoors.daytime),
      // No fallback to the strap's own calorie count. CLAUDE.md pins free-living
      // energy to the server's MET-by-state model, and the device figure is a
      // different model — `steps_card.dart` shows it, attributed, and this cell
      // would not have room to attribute it.
      reading: card?.reading ?? const Withheld<double>(_serverSilent),
      format: (value) => groupedInt(value.round()),
      unit: 'kcal',
      spark: _spark('total_calories'),
      reveals: reveals,
      revealId: 'today.grid.energy',
      foot: total == null ? 'active' : 'active · total ${groupedInt(total.round())}',
    );
  }

  Widget _breathing(MetricHues hues) {
    final vitals = snapshot?.overnightVitals;
    final overnight = vitals?.respiratoryRate;
    final stream = _stream('respiratory_rate');
    return GridModule(
      label: overnight == null ? 'Resp / SpO₂ · strap' : 'Resp / SpO₂',
      tag: hues.tagFor('respiratory_rate'),
      onOpen: () => onOpen(TodayDoors.overnight),
      reading: overnight == null ? stream.reading : Present<double>(overnight),
      format: (value) => value.toStringAsFixed(1),
      unit: 'br/min',
      spark: _spark('respiratory_rate_sleep'),
      reveals: reveals,
      revealId: 'today.grid.respiratory',
      foot: switch (vitals?.spo2Min) {
        final double min => 'spo₂ low ${min.round()}%',
        _ => overnight == null ? _strapFoot('respiratory_rate') : 'overnight',
      },
    );
  }

  // ── the two sources ───────────────────────────────────────────────────────

  /// A server metric card by id, or null when today's payload has none.
  MetricCard? _card(String metric) => snapshot?.metric(metric);

  /// A strap stream, always present — a stream with no samples is a withheld
  /// row, never a missing one.
  DeviceMetric _stream(String metric) => day.metrics.firstWhere(
    (candidate) => candidate.stream.metric == metric,
    orElse: () => _unlistedStream,
  );

  /// One sparkline's values, oldest first.
  List<double> _spark(String metric) =>
      TrendPoint.valuesOf(snapshot?.sparkline(metric) ?? const []);

  /// `30d median 55` — the personal comparison, never a population one.
  String _medianFoot(MetricCard card, {required int digits}) {
    final median = card.median30d;
    if (median == null) {
      return 'no baseline yet';
    }
    return '30d median ${median.toStringAsFixed(digits)}';
  }

  /// `strap · 09:12` — when the sensor last wrote, because it samples on its own
  /// schedule and a reading from 03:00 is a different claim from one from now.
  String _strapFoot(String metric) {
    final at = _stream(metric).measuredAt;
    return at == null ? 'from the strap' : 'strap · ${clockLabel(at)}';
  }

  String? _stepsFoot() {
    final at = day.stepsReadAt;
    final km = day.distanceKm.valueOrNull;
    return [
      'since-midnight counter',
      if (at != null) clockLabel(at),
      if (km != null) '${km.toStringAsFixed(2)} km',
    ].join(' · ');
  }

  /// The server's night, when it sent one.
  Reading<_NightShape> get _serverNight {
    final sleep = snapshot?.lastSleep;
    if (sleep == null) {
      return const Withheld<_NightShape>(_serverSilent);
    }
    return sleep.map(_NightShape.fromServer);
  }

  /// The strap's own night — what this phone can draw with no network at all.
  Reading<_NightShape> get _deviceNight =>
      day.lastNight.map(_NightShape.fromDevice);
}

/// What a grid cell needs from a night, whichever instrument staged it.
///
/// A private shape rather than a shared model: it exists so ONE cell can be
/// drawn from either source without a branch per field, and promoting it would
/// invite it to grow into a third definition of a night beside `LastSleep` and
/// `DeviceNight`.
class _NightShape {
  const _NightShape({
    required this.minutes,
    required this.deepMin,
    required this.remMin,
    required this.spans,
  });

  factory _NightShape.fromServer(LastSleep night) => _NightShape(
    minutes: night.durationMin,
    deepMin: night.minutesIn('deep'),
    remMin: night.minutesIn('rem'),
    spans: night.stages,
  );

  /// The strap stages by wall-clock instants; the hypnogram's x-axis is elapsed
  /// time from onset, so the spans are re-expressed as offsets here. No stage is
  /// invented and none is dropped — an unrecognised `kind` stays unrecognised
  /// and `stage_colors.dart` draws it in the unrecognised grey.
  factory _NightShape.fromDevice(DeviceNight night) {
    final spans = <SleepStageSpan>[];
    var elapsed = 0.0;
    for (final stage in night.stages) {
      final minutes = stage.length.inSeconds / 60;
      spans.add(
        SleepStageSpan(
          stage: stage.kind,
          startOffsetMin: elapsed,
          endOffsetMin: elapsed + minutes,
          durationMin: minutes,
        ),
      );
      elapsed += minutes;
    }
    return _NightShape(
      minutes: night.asleepMin,
      deepMin: night.deepMin,
      remMin: night.remMin,
      spans: spans,
    );
  }

  final int minutes;
  final int deepMin;
  final int remMin;
  final List<SleepStageSpan> spans;
}

/// The refusal a cell carries when the server sent no block for it at all.
///
/// The same reason id and the same sentence `envelope.dart` uses, because it is
/// the same situation — inventing a second wording for it here would be two
/// answers to one question, and a reason id an operator cannot filter on.
/// The stand-in for a stream this build does not list.
///
/// `kDeviceStreams` is a whitelist and every entry of it is always in
/// `DeviceDay.metrics`, so this is unreachable today. It exists rather than a
/// `!` because the alternative to a refusal here is a crash on the home screen
/// the first time somebody renames a stream id.
const DeviceMetric _unlistedStream = DeviceMetric(
  stream: DeviceStream(metric: '?', label: '?', unit: null, decimals: 0),
  reading: Withheld<double>(_serverSilent),
  measuredAt: null,
  sampleCount: 0,
);

const Disclosure _serverSilent = Disclosure(
  reason: unexplainedAbsenceReason,
  message: unexplainedAbsenceMessage,
);
