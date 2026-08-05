/// `Sleep need · debt` — the fortnight's shortfall, as legacy draws it on Today.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1408` —
/// `_SleepDebtModule`. Anatomy unchanged: the average night as a 40 px figure,
/// then either last night's sleep performance or the average gap, a 6 px
/// progress bar of average-against-need, and three stat columns.
///
/// ```text
///   SLEEP NEED · DEBT                                 8h need
///   6.3h  avg / night
///   79%  sleep performance last night · 6.3h
///   ▬▬▬▬▬▬▬▬▬▬▬▬▬▭▭▭▭
///   NIGHTS SHORT   AVG GAP   2-WK DEBT
///      12/14         1.7h       2.0h
/// ```
///
/// The `else if` between the performance line and the gap line is legacy's, and
/// the order matters: performance is about **last night**, the gap is about the
/// fortnight, and legacy prefers the more recent claim when it has one.
///
/// The 85% threshold that tints the performance figure is legacy's own.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_debt.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/widgets/stat_columns.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Sleep need against what the owner actually got.
class SleepDebtCard extends StatelessWidget {
  /// [debt] is the whole `sleep_debt` block.
  const SleepDebtCard({required this.debt, required this.reveals, super.key});

  /// The fortnight's need, averages and accumulated debt.
  final SleepDebt debt;

  /// Where "this bar has already animated" is remembered.
  final RevealRegistry reveals;

  /// Legacy's threshold for a favourable sleep-performance figure.
  static const int goodPerformancePct = 85;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = context.hues.sleep;
    final need = debt.needMin;
    final average = debt.avgTstMin;
    final gap = debt.avgDeficitMin;
    return InstrumentModule(
      label: 'Sleep need · debt',
      tag: tint,
      minHeight: 0,
      trailing: Text(
        '${need ~/ 60}h need',
        style: HType.number(colors.ink3, size: 11, weight: FontWeight.w400),
      ),
      children: [
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              average == null ? '—' : decimalHours(average),
              style: HType.number(
                colors.ink,
                size: 40,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'avg / night',
              style: HType.number(
                colors.ink3,
                size: 13,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
        if (debt.performancePct case final int performance) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                '$performance%',
                style: HType.number(
                  performance >= goodPerformancePct
                      ? colors.accent
                      : colors.alert,
                  size: 15,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _performanceLine(debt.lastTstMin),
                  style: HType.sans(colors.ink3, size: 12.5),
                ),
              ),
            ],
          ),
        ] else if (gap != null && gap > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${decimalHours(gap)} below your ${need ~/ 60}h need',
            style: HType.sans(
              colors.alert,
              size: 13,
              weight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        RevealOnce(
          id: 'today.sleep-debt',
          registry: reveals,
          builder: (context, t) => HProgressBar(
            value: (average ?? 0).toDouble(),
            max: need.toDouble(),
            progress: t,
            height: 6,
            color: tint,
            semanticLabel:
                '${average ?? 0} minutes of a $need-minute need',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            StatColumn(
              label: 'NIGHTS SHORT',
              value: '${debt.nightsBelow}/${debt.nights}',
            ),
            StatColumn(
              label: 'AVG GAP',
              value: gap == null ? '—' : decimalHours(gap),
            ),
            StatColumn(label: '2-WK DEBT', value: decimalHours(debt.debtMin)),
          ],
        ),
      ],
    );
  }

  /// Legacy's `'sleep performance last night${lastTst != null ? ' · …' : ''}'`.
  static String _performanceLine(int? lastTstMin) {
    if (lastTstMin == null) {
      return 'sleep performance last night';
    }
    return 'sleep performance last night · ${decimalHours(lastTstMin)}';
  }
}
