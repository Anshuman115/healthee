/// The hypnogram, with its lane labels doing double duty as the legend.
///
/// **Legacy** `sleep_screen.dart:312–324` and `_hypnoLanes` at 509. A 44 px
/// column of right-aligned lane labels — Awake · REM · Core · Deep, top to bottom
/// — then 8 px, then the chart, all inside a 120 px box. The trailing text is the
/// night's clock range at `num(ink3, 9.5, w400)`.
///
/// `HHypnogram` is the ported painter and its geometry is not touched here; it
/// takes `progress` from the screen's reveal (`shared/reveal_once.dart`).
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/charts/h_hypnogram.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Legacy's "Sleep stages" module.
class HypnogramCard extends StatelessWidget {
  /// [progress] is 0–1 from the screen's reveal.
  const HypnogramCard({required this.night, required this.progress, super.key});

  /// The night to draw.
  final SleepNight night;

  /// How far the reveal has run.
  final double progress;

  /// Legacy's `SizedBox(height: 120)`.
  static const double _height = 120;

  @override
  Widget build(BuildContext context) {
    return InstrumentModule(
      label: 'Sleep stages',
      tag: null,
      minHeight: 0,
      trailing: _range(context),
      children: <Widget>[
        SizedBox(
          height: _height,
          child: night.timeline.isEmpty
              // Legacy drew an empty 120 px box here — `HHypnogram` returns a
              // shrunk SizedBox for an empty span list, so the card kept its
              // frame and said nothing at all. The frame is kept; the silence
              // is not.
              ? const EmptyState(
                  message: 'No staged sleep for this night',
                  hint: 'The strap stages sleep while you wear it. Nothing was '
                      'staged for this session.',
                )
              : Row(
                  children: <Widget>[
                    const _HypnogramLanes(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: HHypnogram(
                        night.timeline,
                        progress: progress,
                        height: _height,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// The clock range, or nothing when there is no session behind the night.
  ///
  /// Legacy printed `— → —` here. A range of two dashes is a value-shaped mark
  /// that says nothing; the card's own body already says the night was not
  /// staged, so the trailing slot goes quiet instead.
  Widget? _range(BuildContext context) {
    final start = night.start;
    final end = night.end;
    if (start == null || end == null) {
      return null;
    }
    return Text(
      '${clock(start)} → ${clock(end)}',
      style: HType.number(context.colors.ink3, size: 9.5, weight: FontWeight.w400),
    );
  }
}

/// Legacy's `_hypnoLanes` — the left-hand labels, top to bottom.
class _HypnogramLanes extends StatelessWidget {
  const _HypnogramLanes();

  /// Legacy's order and legacy's words. `Core` is legacy's name for what the
  /// server calls `light`; both resolve to one colour.
  static const List<(String, String)> _lanes = <(String, String)>[
    ('Awake', 'awake'),
    ('REM', 'rem'),
    ('Core', 'core'),
    ('Deep', 'deep'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final (label, stage) in _lanes)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hues.sleepStage(stage),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HType.label(colors.ink2, size: 9, tracking: 0.02),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
