/// `H.miniTrend` — one reading, its recent shape, and one line about both.
///
/// ```js
/// H.miniTrend = (title,tone,value,unit,values,limits,route,note,icon) =>
///   H.panel(title, tone,
///     `${H.value(value,unit)}${H.charts.line(values,{compact:true})}${H.note(note)}`,
///     route, icon);
/// ```
///
/// Four of these are on Today — overnight HRV, resting heart, blood oxygen and
/// (as the left half of the last pair) the nightly minimum — and they are the
/// same panel four times, so they are one widget four times.
///
/// ## What it does with a reading it was not given
///
/// A [Withheld] reading draws the panel at **full height** with an em dash where
/// the figure goes and the server's own reason where the note goes. Not a
/// `WithheldPanel`: a half-width slot has no room for the dashed hole and its
/// sentence side by side, and a row whose left half changes shape because a
/// number is missing is a layout that announces the absence louder than the
/// words do. The reason is still on screen, in words, inside the card that owns
/// the number — which is the whole contract.
///
/// A series with fewer than two measured samples draws **nothing** and keeps its
/// slot: `V02Sparkline` returns a `ChartVoid` of the same height, so the pair
/// stays level whether or not either half has a trend.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/charts/v02/v02_sparkline.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// A half-width panel: a figure, a sparkline, and a sentence.
class MiniTrendPanel extends StatelessWidget {
  /// [series] is oldest first and is never padded — see `today_facts.dart`.
  const MiniTrendPanel({
    required this.title,
    required this.icon,
    required this.tone,
    required this.reading,
    required this.series,
    required this.revealId,
    required this.reveals,
    required this.note,
    this.infoKey,
    this.label,
    this.unit,
    this.digits = 0,
    this.onDetails,
    super.key,
  });

  /// `.chart` inside a twin panel, at the prototype's compact proportions.
  static const double sparklineHeight = 30;

  /// The gap between the figure and the line, and the line and the note.
  static const double chartGap = 8;

  /// The panel's own title.
  final String title;

  /// Drawn before it, in the family colour.
  final IconData icon;

  /// Which family everything inside resolves.
  final Tone tone;

  /// The figure, with its honesty state.
  final Reading<double> reading;

  /// The recent nights or days behind it.
  final List<double> series;

  /// This chart's reveal identity. Stable across rebuilds and reorderings.
  final String revealId;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// The sentence under the line.
  final String note;

  /// Opens the metric's plain-language explainer. See `PanelHead.infoKey`.
  final String? infoKey;

  /// The metric's owner-facing name, for a disclosure sheet's subtitle.
  final String? label;

  /// The figure's unit.
  final String? unit;

  /// Decimal places in the figure.
  final int digits;

  /// Opens the metric's own screen. Null draws no action.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return ReadingView<double>(
      reading: reading,
      label: label ?? title,
      caveatCarrier: CaveatCarrier.insideCard,
      withheldBuilder: (context, disclosure) =>
          _panel(value: '—', note: disclosure.message),
      builder: (context, value) =>
          _panel(value: value.toStringAsFixed(digits), note: note),
    );
  }

  Widget _panel({required String value, required String note}) => Panel(
    tone: tone,
    label: label ?? title,
    head: PanelHead(
      title: title,
      icon: icon,
      infoKey: infoKey,
      actionLabel: onDetails == null ? null : 'Details',
      onAction: onDetails,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PanelValue(value, unit: unit),
        const SizedBox(height: chartGap),
        RevealOnce(
          id: revealId,
          registry: reveals,
          builder: (context, t) => V02Sparkline(
            <double?>[...series],
            progress: t,
            height: sparklineHeight,
          ),
        ),
        PanelNote(note),
      ],
    ),
  );
}
