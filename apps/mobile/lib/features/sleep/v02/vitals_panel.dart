/// `Your body overnight` — five measurements, each with its own fortnight.
///
/// `design/mobile-preview/panels.js::H.overnightVitals`:
///
/// ```js
/// `<div class="vitals-table">${[
///   ['heart','Resting heart', n.rhr,'bpm','heart',   rhr14,        [40,70], 'rhr'],
///   ['fitness','HRV',         n.hrv_sleep_avg,'ms','activity', hrv14, [25,65], 'hrv'],
///   ['oxygen','Blood oxygen', n.spo2_avg,'%','drop',  spo2_14,      [90,100],'spo2'],
///   ['oxygen','Breathing',    n.respiratory_rate,'/min','activity', br14, [10,20],'breathing'],
///   ['stress','Skin temperature', n.skin_temp_c,'°C','sun', temp14, [30,36],'temperature'],
/// ].map(([tone,label,value,unit,icon,values,limits,route]) =>
///   `<a class="vital-row" data-tone="${tone}" href="#metric/${route}">
///      <span class="vital-label">${H.icon(icon)}${label}</span>
///      ${H.charts.line(values,{compact:true})}
///      <strong>${value}<small> ${unit}</small></strong></a>`).join('')}</div>`
/// ```
/// ```css
/// .vital-row { display:grid; grid-template-columns:minmax(0,1fr) 75px 66px;
///              align-items:center; gap:8px; padding-block:12px;
///              border-bottom:1px solid var(--line) }
/// .vital-row:last-child { border:0; padding-bottom:0 }
/// .vital-row .icon      { color:var(--family) }
/// .vital-row .sparkline { margin:0; height:25px }
/// @media(max-width:359px) .vital-row { grid-template-columns:minmax(0,1fr) 50px 62px }
/// ```
///
/// ## Five families in one panel, and no widget takes a colour
///
/// `data-tone` sits on the **row**, not the panel, so each row's glyph and its
/// spark are that measurement's own family while the panel head stays oxygen's.
/// Each row is a `ToneScope`; the sparkline reads the family out of it.
///
/// ## What the strap refused
///
/// Every figure is a `Reading`. A withheld one draws a dash in its slot, and the
/// server's reason is written out under the table, naming the measurement — one
/// note listing three refusals, rather than three sentences threaded between
/// rows where each would read as a caveat on the row below it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/sleep_type_scale.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/shared/charts/v02/v02_sparkline.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// One row of the overnight table.
@immutable
class Vital {
  /// A measurement, its family, its fortnight and where it goes when tapped.
  const Vital({
    required this.label,
    required this.tone,
    required this.icon,
    required this.unit,
    required this.reading,
    required this.series,
    required this.metric,
    this.digits = 0,
  });

  /// What it is called.
  final String label;

  /// Which family it belongs to.
  final Tone tone;

  /// Its glyph.
  final IconData icon;

  /// The unit beside the figure.
  final String unit;

  /// Last night's value, with its honesty state.
  final Reading<double> reading;

  /// The fortnight behind it, oldest first, gaps kept as nulls.
  final List<double?> series;

  /// The metric this row opens.
  final String metric;

  /// How many decimals the figure carries.
  final int digits;
}

/// `Your body overnight` — the five overnight measurements.
class OvernightPanel extends StatelessWidget {
  /// [night] is the session; [recent] is the fortnight, newest first.
  const OvernightPanel({
    required this.night,
    required this.recent,
    required this.reveals,
    this.onOpenMetric,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Your body overnight';

  /// `.sparkline { height:25px }`.
  static const double sparkHeight = 25;

  /// `.vital-row { padding-block:12px }`.
  static const double rowPad = 12;

  /// `gap:8px`.
  static const double columnGap = 8;

  /// `grid-template-columns: … 75px 66px`.
  static const double sparkWidth = 75;
  static const double valueWidth = 66;

  /// The same two under the prototype's 359 px breakpoint.
  static const double narrowSparkWidth = 50;
  static const double narrowValueWidth = 62;

  /// The night being read.
  final SleepNight night;

  /// The fortnight, newest first — the order `/api/sleep` sends.
  final List<SleepNight> recent;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens one measurement's own history.
  final void Function(String metric)? onOpenMetric;

  /// The five rows, in the prototype's order.
  List<Vital> get vitals => <Vital>[
    Vital(
      label: 'Resting heart',
      tone: Tone.heart,
      icon: Icons.favorite_border,
      unit: 'bpm',
      reading: night.restingHr,
      series: _series((night) => night.restingHr.valueOrNull),
      metric: 'rhr',
    ),
    Vital(
      label: 'HRV',
      tone: Tone.fitness,
      icon: Icons.show_chart,
      unit: 'ms',
      reading: night.hrvSleepAvg,
      series: _series((night) => night.hrvSleepAvg.valueOrNull),
      metric: 'hrv_sleep_avg',
    ),
    Vital(
      label: 'Blood oxygen',
      tone: Tone.oxygen,
      icon: Icons.water_drop_outlined,
      unit: '%',
      reading: night.spo2Avg,
      series: _series((night) => night.spo2Avg.valueOrNull),
      metric: 'spo2_avg',
    ),
    Vital(
      label: 'Breathing',
      tone: Tone.oxygen,
      icon: Icons.air,
      unit: '/min',
      reading: night.respiratoryRate,
      series: _series((night) => night.respiratoryRate.valueOrNull),
      metric: 'respiratory_rate',
    ),
    Vital(
      label: 'Skin temperature',
      tone: Tone.stress,
      icon: Icons.wb_sunny_outlined,
      unit: '°C',
      reading: night.skinTempC,
      series: _series((night) => night.skinTempC.valueOrNull),
      metric: 'skin_temp_c',
      digits: 1,
    ),
  ];

  /// Oldest first, with a night the strap did not measure kept as a gap.
  List<double?> _series(double? Function(SleepNight night) read) =>
      <double?>[for (final night in recent.reversed) read(night)];

  @override
  Widget build(BuildContext context) {
    final rows = vitals;
    return Panel(
      tone: Tone.oxygen,
      label: 'Overnight vitals',
      head: PanelHead(
        title: title,
        icon: Icons.favorite_border,
        infoKey: 'sleep',
        actionLabel: onOpenMetric == null ? null : 'Details',
        onAction: onOpenMetric == null
            ? null
            : () => onOpenMetric!(rows.first.metric),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < rows.length; i++)
            _VitalRow(
              vital: rows[i],
              reveals: reveals,
              last: i == rows.length - 1,
              onOpen: onOpenMetric == null
                  ? null
                  : () => onOpenMetric!(rows[i].metric),
            ),
          if (refusals(rows) case final List<String> lines
              when lines.isNotEmpty)
            PanelNote(lines.join('\n')),
        ],
      ),
    );
  }

  /// The server's own reason for each measurement it did not send.
  static List<String> refusals(List<Vital> rows) => <String>[
    for (final vital in rows)
      if (vital.reading case Withheld<double>(:final disclosure))
        '${vital.label}: ${disclosure.message}',
  ];
}

/// One `.vital-row`: label, fortnight, figure.
class _VitalRow extends StatelessWidget {
  const _VitalRow({
    required this.vital,
    required this.reveals,
    required this.last,
    this.onOpen,
  });

  final Vital vital;
  final RevealRegistry reveals;
  final bool last;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => ToneScope(
    tone: vital.tone,
    child: Builder(builder: _body),
  );

  Widget _body(BuildContext context) {
    final colors = context.colors;
    final narrow =
        MediaQuery.sizeOf(context).width < SleepType.narrowWidth;
    final value = vital.reading.valueOrNull;
    final row = Padding(
      padding: EdgeInsets.only(
        top: OvernightPanel.rowPad,
        bottom: last ? 0 : OvernightPanel.rowPad,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(vital.icon, size: 15, color: context.family),
                const SizedBox(width: OvernightPanel.columnGap),
                Flexible(
                  child: Text(
                    vital.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SleepType.vitalLabel.copyWith(color: colors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: OvernightPanel.columnGap),
          SizedBox(
            width: narrow
                ? OvernightPanel.narrowSparkWidth
                : OvernightPanel.sparkWidth,
            child: RevealOnce(
              id: 'sleep.vital.${vital.metric}',
              registry: reveals,
              builder: (context, t) => V02Sparkline(
                vital.series,
                progress: t,
                height: OvernightPanel.sparkHeight,
              ),
            ),
          ),
          const SizedBox(width: OvernightPanel.columnGap),
          SizedBox(
            width: narrow
                ? OvernightPanel.narrowValueWidth
                : OvernightPanel.valueWidth,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: value == null
                        ? '—'
                        : value.toStringAsFixed(vital.digits),
                    style: SleepType.vitalValue.copyWith(
                      color: value == null ? colors.ink3 : colors.ink,
                    ),
                  ),
                  TextSpan(
                    text: ' ${vital.unit}',
                    style: SleepType.vitalUnit.copyWith(color: colors.ink2),
                  ),
                ],
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
    final bordered = last
        ? row
        : DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.line, width: hairline),
              ),
            ),
            child: row,
          );
    return HTap(
      onTap: onOpen,
      semanticLabel: '${vital.label} history',
      child: bordered,
    );
  }
}
