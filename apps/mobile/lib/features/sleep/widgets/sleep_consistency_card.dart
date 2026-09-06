/// Bedtime and wake-time regularity — the chart, the numbers, the odd nights.
///
/// **Legacy** `sleep_screen.dart:786` (`_SleepConsistencyCard`). A 150 px
/// `HTimingChart`, the two-key legend, a sunken block carrying the band in hours
/// at `num(verdict, 22, w700)` with the server's verdict sentence and the SRI
/// beside it, the median bed/wake line with a VERY LATE stamp, then the
/// off-pattern nights, then the accent-washed action, then the closing caption.
///
/// ## Two honesty changes
///
/// **The SRI arrives withheld and is now rendered withheld.**
/// `read/sleep_extras.py::_sri_block` nulls `sri` whenever it is not current and
/// moves the value into `sri_withheld` "where it carries its own date and age" —
/// legacy read `data['sri']`, found null, and simply drew nothing, which is the
/// silence that block exists to break. The reason and the date now reach the card.
///
/// **The action is server-authored prose and goes through the grounded
/// renderer.** Legacy printed it as a plain string; any `[note_id]` in it would
/// have reached the owner as literal brackets, and its sources reached nobody.
///
/// The amber verdict colour was an inline `const Color(0xFFE0A33E)` in legacy
/// (`sleep_screen.dart:804`) — one of the three sites `palette.dart` names. It is
/// `colors.unf` here, the same value.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/features/sleep/widgets/sleep_legend.dart';
import 'package:healthee/shared/charts/h_timing_chart.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:solar_icons/solar_icons.dart';

/// Legacy's "Bedtime · wake-time · N nights" module.
class SleepConsistencyCard extends StatelessWidget {
  /// [bedtime] and [wake] are hours-from-18:00, chronological.
  const SleepConsistencyCard({
    required this.bedtime,
    required this.wake,
    required this.consistency,
    required this.progress,
    super.key,
  });

  /// Bedtimes on the 18:00 scale, oldest first.
  final List<double> bedtime;

  /// Wake times on the same scale, oldest first.
  final List<double> wake;

  /// The server's regularity block, or null when it has not answered.
  final SleepConsistency? consistency;

  /// How far the reveal has run.
  final double progress;

  /// Legacy's `SizedBox(height: 150)`.
  static const double _chartHeight = 150;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final block = consistency;
    return InstrumentModule(
      label: 'Bedtime · wake-time · ${bedtime.length} nights',
      tag: null,
      infoKey: 'sleep_consistency',
      minHeight: 0,
      children: <Widget>[
        SizedBox(
          height: _chartHeight,
          child: HTimingChart(
            bedtime: bedtime,
            wake: wake,
            progress: progress,
            height: _chartHeight,
          ),
        ),
        const SizedBox(height: 10),
        SleepLegend(
          <LegendKey>[
            LegendKey(hues.sleep, 'Bedtime'),
            LegendKey(hues.movement, 'Wake-time'),
          ],
          spacing: 16,
        ),
        if (block != null && block.hasBand) ...<Widget>[
          const SizedBox(height: 12),
          _BandBlock(block: block),
        ],
        if (block != null && block.irregularNights.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Off-pattern nights (>2 h from your usual) — these drag your score:',
            style: HType.sans(
              colors.ink2,
              size: 11.5,
              weight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          for (final night in block.irregularNights.take(4)) _OddNight(night: night),
        ],
        if (block?.action case final String action when action.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _ActionBlock(action: action),
        ],
        const SizedBox(height: 10),
        Text(
          'Flat lines = consistent timing; drift = circadian variability. '
          'Tightest sleepers (~1 h band) have the lowest mortality (Windred 2024).',
          style: HType.sans(colors.ink3, size: 11.5, height: 1.5),
        ),
      ],
    );
  }
}

/// The sunken block: the band, the verdict, the SRI, the median times.
class _BandBlock extends StatelessWidget {
  const _BandBlock({required this.block});

  final SleepConsistency block;

  /// Legacy's thresholds for the band colour.
  static const double _tight = 1.5;
  static const double _moderate = 2.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final band = block.onsetBandH!;
    final verdictColour = band <= _tight
        ? colors.fav
        : band <= _moderate
        ? colors.unf
        : hues.heart;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: colors.surface2,
        shape: hSquircle(Radii.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${band.toStringAsFixed(1)} h',
                style: HType.number(verdictColour, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'typical bedtime band\n${block.onsetBand ?? ''}',
                  style: HType.sans(colors.ink2, size: 11.5, height: 1.3),
                ),
              ),
              // The SRI is the one field on this endpoint that arrives with its
              // own withheld block. `ReadingView` renders that block's message
              // where the number would have been.
              Flexible(
                child: ReadingView<double>(
                  reading: block.sri,
                  label: 'Sleep regularity',
                  builder: (context, sri) => Text(
                    'SRI ${sri.round()}',
                    style: HType.number(hues.fitness, size: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  _times(block),
                  style: HType.sans(colors.ink3, size: 11, height: 1.4),
                ),
              ),
              if (block.late) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: ShapeDecoration(
                    color: hues.heart.withValues(alpha: 0.15),
                    shape: hSquircle(Radii.button),
                  ),
                  child: Text(
                    'VERY LATE',
                    style: HType.number(hues.heart, size: 8.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Legacy wrote `Bed ~— · wake ~—` when either was missing. Each half is
  /// dropped instead, so the line states only what was measured.
  static String _times(SleepConsistency block) {
    final parts = <String>[
      if (block.medianBedtime case final String bed) 'Bed ~$bed',
      if (block.meanWake case final String wake) 'wake ~$wake',
    ];
    return parts.isEmpty ? 'No median bedtime yet' : parts.join(' · ');
  }
}

/// One off-pattern night.
class _OddNight extends StatelessWidget {
  const _OddNight({required this.night});

  final IrregularNight night;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final delta = night.deltaH;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Icon(SolarIconsOutline.moonSleep, size: 13, color: colors.ink3),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '${shortDate(night.date)} · bed ${night.bedtime ?? 'unrecorded'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HType.sans(colors.ink2, size: 11.5),
            ),
          ),
          const Spacer(),
          if (delta != null)
            Text(
              '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} h',
              style: HType.number(hues.heart, size: 10.5),
            ),
        ],
      ),
    );
  }
}

/// The accent-washed action line. Server-authored, so grounded.
class _ActionBlock extends StatelessWidget {
  const _ActionBlock({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: ShapeDecoration(
        color: colors.accent.withValues(alpha: 0.10),
        shape: hSquircle(Radii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(SolarIconsBold.lightbulb, size: 15, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: GroundedProse(
              text: action,
              style: HType.sans(colors.ink, size: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
