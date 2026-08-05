/// Naps — the daytime sleeps the strap tagged, with their stage bars.
///
/// **Legacy** `sleep_screen.dart:445–494` and `_napStageBar` at 122. Up to eight
/// naps, each a 50 px date column, a 9 px stage bar with 3 px corners, the
/// duration right-aligned, then a second line inset 62 px carrying the clock
/// range and the midpoint. Under them, legacy's own four-stage legend — 8 px
/// squares at a **2 px** corner with `sans(ink3, 9.5)` labels and 13 px of right
/// padding, which is a different legend from the one under the charts and is kept
/// different. Then the caption about late naps.
///
/// **Legacy labels light sleep `light` here and `Core` in the breakdown above.**
/// One stage, two words, one screen. Ported as found; reported.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/instrument_module.dart';

/// Legacy's "Naps · 30 days" module.
class NapsCard extends StatelessWidget {
  /// [naps] is newest first.
  const NapsCard({required this.naps, super.key});

  /// Every nap in the window.
  final List<SleepNap> naps;

  /// Legacy draws at most eight.
  static const int _shown = 8;

  /// Legacy's own vocabulary for this legend, in its own order.
  static const List<(String, String)> _legend = <(String, String)>[
    ('core', 'light'),
    ('deep', 'deep'),
    ('rem', 'rem'),
    ('awake', 'awake'),
  ];

  /// Total nap minutes across the window.
  double get totalMin => naps.fold<double>(0, (sum, nap) => sum + (nap.durationMin ?? 0));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return InstrumentModule(
      label: 'Naps · 30 days',
      tag: null,
      minHeight: 0,
      trailing: Text(
        '${naps.length} · ${hoursMinutes(totalMin.round())}',
        style: HType.number(colors.ink3, size: 10, weight: FontWeight.w400),
      ),
      children: <Widget>[
        for (final nap in naps.take(_shown)) _NapRow(nap: nap),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            for (final (stage, label) in _legend)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 13),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hues.sleepStage(stage),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HType.sans(colors.ink3, size: 9.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'Daytime sleep adds to your total — but long or late naps can blunt '
          'the next night’s sleep drive.',
          style: HType.sans(colors.ink3, size: 11.5, height: 1.5),
        ),
      ],
    );
  }
}

class _NapRow extends StatelessWidget {
  const _NapRow({required this.nap});

  final SleepNap nap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final start = nap.start;
    final end = nap.end;
    final duration = nap.durationMin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 50,
                child: Text(
                  napDate(nap.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HType.sans(colors.ink, size: 13.5, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _NapStageBar(stages: nap.stages)),
              const SizedBox(width: 12),
              // A nap with no duration is not drawn as `—`: the strap gives every
              // session a start and an end, so an absent duration is a payload
              // this app cannot read, and it says nothing rather than a dash.
              if (duration != null)
                Text(
                  napDuration(duration),
                  style: HType.number(colors.ink2, size: 12.5, weight: FontWeight.w500),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 62),
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    start == null || end == null ? '' : napRange(start, end),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HType.number(colors.ink3, size: 10.5, weight: FontWeight.w400),
                  ),
                ),
                const Spacer(),
                if (nap.midpointLocal case final String midpoint)
                  Flexible(
                    child: Text(
                      'mid $midpoint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HType.number(colors.ink3, size: 10.5, weight: FontWeight.w400),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy's `_napStageBar` — segment width ∝ stage minutes.
class _NapStageBar extends StatelessWidget {
  const _NapStageBar({required this.stages});

  final List<NapStage> stages;

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    final drawn = <NapStage>[
      for (final stage in stages)
        if (stage.durationMin > 0) stage,
    ];
    if (drawn.isEmpty) {
      return const SizedBox(height: 9);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 9,
        child: Row(
          children: <Widget>[
            for (final stage in drawn)
              Expanded(
                flex: (stage.durationMin * 10).round().clamp(1, 99999),
                child: ColoredBox(
                  color: hues.sleepStage(normaliseStage(stage.stage)),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
