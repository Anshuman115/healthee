/// The server's metric cards: today's value, a sparkline, and **your** normal.
///
/// Brief §4.1's metric strip and §3's baseline comparison in one card. The
/// comparison is the app's real value — *"Below your usual range of 63 to 79
/// ms"*, your number against your normal, not a population's — so a card with no
/// baseline says so plainly rather than falling silent.
///
/// **One outer card, hairline rows.** Brief §2's first "never" is
/// card-inside-a-card, and a strip of seven framed cards is that rule broken
/// seven times. A withheld row is drawn with an inline [ValueHole] and its
/// reason, in the value's own position, rather than by nesting a `WithheldCard`
/// frame inside this one.
///
/// The `switch` over [Reading] is exhaustive by the language's own rules, so a
/// fifth honesty state stops this file compiling until somebody decides what a
/// row of it looks like.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/metric_card.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// The server's metric cards, in one card with divided rows.
class ServerMetricStrip extends StatelessWidget {
  /// [sparklines] is keyed by metric id; a metric with none draws no chart.
  const ServerMetricStrip({
    required this.metrics,
    required this.sparklines,
    required this.reveals,
    super.key,
  });

  /// The cards, in server order.
  final List<MetricCard> metrics;

  /// Fourteen days per metric id.
  final Map<String, List<TrendPoint>> sparklines;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Against your own baseline', style: text.labelSmall),
          for (final card in metrics) ...[
            Divider(color: colors.line2, height: Insets.lg, thickness: hairline),
            _MetricRow(
              card: card,
              series: sparklines[card.metric] ?? const [],
              reveals: reveals,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.card,
    required this.series,
    required this.reveals,
  });

  final MetricCard card;
  final List<TrendPoint> series;
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.label, style: text.titleSmall),
                  const SizedBox(height: Insets.xs),
                  Text(
                    _comparison(card),
                    style: text.bodySmall?.copyWith(color: colors.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.md),
            switch (card.reading) {
              Present<double>(:final value) => _Value(card: card, value: value),
              Caveated<double>(:final value) => _Value(card: card, value: value),
              Withheld<double>() || Excluded<double>() => const Padding(
                padding: EdgeInsets.only(top: 2),
                child: ValueHole.inline(),
              ),
            },
          ],
        ),
        if (series.length >= 2) ...[
          const SizedBox(height: Insets.sm),
          RevealOnce(
            id: 'sparkline-${card.metric}',
            registry: reveals,
            builder: (context, t) => HArea(
              TrendPoint.valuesOf(series),
              color: colors.accent,
              progress: t,
              height: 30,
              unit: card.unit ?? '',
              digits: card.median30d != null && card.median30d! < 10 ? 1 : 0,
            ),
          ),
        ],
      ],
    );
  }

  /// Your number against **your** normal — or an honest note that there is no
  /// normal yet. Weight never gets one, and a new owner has none for anything.
  static String _comparison(MetricCard card) {
    return switch (card.reading) {
      Withheld<double>(:final disclosure) => disclosure.message,
      Excluded<double>(:final exclusions) =>
        exclusions.isEmpty ? 'Left out of this view' : exclusions.first.message,
      _ => _baselineSentence(card),
    };
  }

  static String _baselineSentence(MetricCard card) {
    final median = card.median30d;
    if (median == null) {
      return 'No 30-day baseline for this — shown plainly, with nothing to '
          'compare it against.';
    }
    final z = card.z;
    if (z == null) {
      return 'Your usual is ${_number(median)}${_unit(card)}.';
    }
    if (z.abs() < 0.5) {
      return 'Inside your usual range, around ${_number(median)}${_unit(card)}.';
    }
    final side = z > 0 ? 'Above' : 'Below';
    return '$side your usual ${_number(median)}${_unit(card)} — '
        '${z.abs().toStringAsFixed(1)}σ'
        '${card.anomalous ? ', outside your normal' : ''}.';
  }

  static String _unit(MetricCard card) =>
      card.unit == null ? '' : ' ${card.unit}';

  static String _number(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

class _Value extends StatelessWidget {
  const _Value({required this.card, required this.value});

  final MetricCard card;
  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value == value.roundToDouble()
              ? value.round().toString()
              : value.toStringAsFixed(1),
          style: text.headlineSmall,
        ),
        if (card.unit case final String unit) ...[
          const SizedBox(width: Insets.xs),
          Text(unit, style: text.labelSmall?.copyWith(color: colors.ink3)),
        ],
      ],
    );
  }
}
