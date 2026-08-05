/// The night's stage split — the segment bar and its four rows.
///
/// **Legacy** `sleep_screen.dart:328–336` (`Breakdown`), `_SegBar` at 609 and
/// `_stageRow` at 550. Unchanged: the 14 px bar with a 4 px clip, flex weighted
/// by `minutes × 100`, then one row per stage with a 9 px swatch, the name at
/// `sans(ink, 14, w600)`, the duration at `num(ink2, 13)` and a right-aligned
/// 36 px percentage at `num(ink3, 11)`.
///
/// **Legacy's word for `light` is `Core` here and `light` in the naps legend.**
/// Both are ported as found — see the port notes.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/instrument_module.dart';

/// One row of the breakdown: a stage, its minutes, its share.
typedef StageRow = ({String key, String label, double minutes});

/// Legacy's "Breakdown" module.
class BreakdownCard extends StatelessWidget {
  /// [night] supplies the stage totals.
  const BreakdownCard({required this.night, super.key});

  /// The night to break down.
  final SleepNight night;

  /// Legacy's rows, in legacy's order, with legacy's labels.
  List<StageRow> get rows => <StageRow>[
    (key: 'deep', label: 'Deep', minutes: night.stages.deep),
    (key: 'core', label: 'Core', minutes: night.stages.light),
    (key: 'rem', label: 'REM', minutes: night.stages.rem),
    (key: 'awake', label: 'Awake', minutes: night.stages.awake),
  ];

  @override
  Widget build(BuildContext context) {
    final total = night.stages.total;
    return InstrumentModule(
      label: 'Breakdown',
      tag: null,
      minHeight: 0,
      children: <Widget>[
        const SizedBox(height: 4),
        _SegmentBar(rows: rows, total: total),
        const SizedBox(height: 16),
        for (final row in rows) _StageRow(row: row, total: total),
      ],
    );
  }
}

/// The stacked bar. Legacy's `_SegBar`.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.rows, required this.total});

  final List<StageRow> rows;
  final double total;

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: <Widget>[
          for (final row in rows)
            if (row.minutes > 0)
              Expanded(
                flex: (row.minutes * 100).round(),
                child: Container(height: 14, color: hues.sleepStage(row.key)),
              ),
        ],
      ),
    );
  }
}

/// One stage row. Legacy's `_stageRow`.
class _StageRow extends StatelessWidget {
  const _StageRow({required this.row, required this.total});

  final StageRow row;
  final double total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final percent = total > 0 ? (100 * row.minutes / total).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: hues.sleepStage(row.key),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              row.label,
              style: HType.sans(colors.ink, weight: FontWeight.w600),
            ),
          ),
          Text(
            hoursMinutes(row.minutes),
            style: HType.number(colors.ink2, size: 13, weight: FontWeight.w400),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: HType.number(colors.ink3, size: 11, weight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
