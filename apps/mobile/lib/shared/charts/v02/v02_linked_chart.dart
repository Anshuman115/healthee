/// **The showpiece.** Two signals, stacked, sharing one hour cursor and nothing
/// else.
///
/// Heart rate and stress across a day is the case it was built for: two things
/// the owner can watch move together, on two axes that are each labelled in
/// their own units, with one cursor that puts both readings side by side in the
/// same instant.
///
/// ## The caveat is part of the chart, not decoration on it
///
/// The prototype's own caption is the honest framing and it ships as the
/// widget's default: *"A coinciding change is context, not proof that one signal
/// caused the other."* Two traces drawn one above the other with a shared cursor
/// is a machine for producing causal readings — that is exactly what makes the
/// chart useful, and exactly what makes it dangerous. So the sentence belongs to
/// the chart rather than to whichever card happens to embed it, because a caveat
/// a call site can forget is a caveat that will be forgotten.
///
/// ## Both panes or neither
///
/// If either signal is too short to draw, the whole chart withholds and keeps
/// its slot. A "linked" chart with one live pane is not a weaker version of this
/// chart — it is a different chart, drawn under a title promising a comparison
/// the reader cannot make.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/charts/v02/chart_ink.dart';
import 'package:healthee/shared/charts/v02/chart_scrub.dart';
import 'package:healthee/shared/charts/v02/chart_ticks.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';
import 'package:healthee/shared/charts/v02/linked_painter.dart';

export 'package:healthee/shared/charts/v02/linked_painter.dart'
    show LinkedPane;

/// Two panes, one cursor, independent labelled scales.
class V02LinkedChart extends StatelessWidget {
  /// [panes] are drawn top first and must be sample-aligned: index i is the
  /// same instant in every pane.
  const V02LinkedChart(
    this.panes, {
    required this.progress,
    this.captions = const <String>[],
    this.sampleLabels = const <String>[],
    this.height = 236,
    this.caveat = coincidenceCaveat,
    this.semanticLabel,
    super.key,
  });

  /// The prototype's own framing, and the reason this chart may be drawn.
  static const String coincidenceCaveat =
      'A coinciding change is context, not proof that one signal caused '
      'the other.';

  /// The signals, top first. Built for two.
  final List<LinkedPane> panes;

  /// 0–1 from `RevealOnce`.
  final double progress;

  /// The two edge captions, written once under the bottom pane.
  final List<String> captions;

  /// One label per sample, for the readout's time.
  final List<String> sampleLabels;

  /// The plot stack's height, excluding the readout and the caveat.
  final double height;

  /// The sentence under the chart. Overridable, not omissible.
  final String caveat;

  /// What a screen reader is told the chart is.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final samples = _sampleCount;
    if (panes.length < 2 ||
        panes.any((pane) => !canDrawSeries(pane.values)) ||
        samples < 2) {
      return ChartVoid(height: height + ChartScrub.readoutHeight);
    }
    final lanes = <LinkedLane>[
      for (final pane in panes)
        LinkedLane(
          pane: pane,
          ink: ChartInk.tone(context, pane.tone),
          ticks: ChartTicks.nice(pane.values.whereType<double>()),
        ),
    ];
    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ChartScrub(
          sampleCount: samples,
          height: height,
          metrics: linkedScrubMetrics,
          chart: (context, index) => CustomPaint(
            painter: LinkedPainter(
              lanes: lanes,
              progress: progress,
              captions: captions,
              touch: index,
            ),
          ),
          readout: (context, index) => _LinkedReadout(
            panes: panes,
            index: index,
            time: index != null && index < sampleLabels.length
                ? sampleLabels[index]
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            caveat,
            style: TypeScale.panelNote.copyWith(color: context.colors.ink2),
          ),
        ),
      ],
    );
    final label = semanticLabel;
    return label == null ? chart : Semantics(label: label, child: chart);
  }

  /// The shortest pane decides, so no cursor lands on a sample a pane lacks.
  int get _sampleCount => panes.isEmpty
      ? 0
      : panes
            .map((pane) => pane.values.length)
            .reduce((a, b) => a < b ? a : b);
}

/// Both readings and the instant, or the invitation to ask for them.
class _LinkedReadout extends StatelessWidget {
  const _LinkedReadout({
    required this.panes,
    required this.index,
    required this.time,
  });

  final List<LinkedPane> panes;
  final int? index;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (index == null) {
      return const ChartReadoutText(
        'Touch the chart to compare the same moment',
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final pane in panes) ...<Widget>[
          ToneScope(
            tone: pane.tone,
            child: _PaneReading(text: pane.readingAt(index)),
          ),
          const SizedBox(width: 12),
        ],
        if (time != null)
          Text(
            time!,
            style: TypeScale.colourKey.copyWith(color: colors.ink3),
          ),
      ],
    );
  }
}

/// One reading with its family dot. The dot resolves the tone it is wrapped in,
/// so a key can never disagree with the trace it names.
class _PaneReading extends StatelessWidget {
  const _PaneReading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: context.family,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        text,
        style: TypeScale.colourKey.copyWith(color: context.colors.ink2),
      ),
    ],
  );
}
