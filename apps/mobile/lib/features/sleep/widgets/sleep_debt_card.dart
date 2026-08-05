/// Sleep debt — the last seven nights against the 8 h reference.
///
/// **Legacy** `sleep_screen.dart:387–408`. The shortfall at `num(cHeart, 28,
/// w700)` with "shortfall vs 8h" beside it, a 130 px `HDebtBars`, then the three
/// legend keys: Met 8h · Short · the dashed 8h target.
///
/// The debt is legacy's arithmetic verbatim — `Σ clamp(480 − tst, 0, 480)` over
/// the seven nights that HAVE a total. A night with no measured sleep is not a
/// night of zero sleep, so it is left out of the sum rather than counted as an
/// eight-hour debt; that is legacy's behaviour too (its comprehension filters
/// `x['tst_min'] != null`), and it is worth stating because the other reading of
/// the same code would double the number on a week the strap was off.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/features/sleep/widgets/sleep_legend.dart';
import 'package:healthee/features/sleep/widgets/sleep_performance_card.dart';
import 'package:healthee/shared/charts/h_debt_bars.dart';
import 'package:healthee/shared/instrument_module.dart';

/// One measured night in the debt window.
typedef DebtNight = ({double totalMin, String label});

/// Legacy's "Sleep debt · last 7 nights" module.
class SleepDebtCard extends StatelessWidget {
  /// [nights] is the seven-night window, **oldest first**.
  const SleepDebtCard({required this.nights, required this.progress, super.key});

  /// The measured nights, chronological.
  final List<DebtNight> nights;

  /// How far the reveal has run.
  final double progress;

  /// Legacy's `SizedBox(height: 130)`.
  static const double _chartHeight = 130;

  /// Σ of each night's shortfall against the reference, clamped at zero.
  double get shortfallMin => nights.fold<double>(
    0,
    (sum, night) => sum + (kSleepNeedMin - night.totalMin).clamp(0.0, kSleepNeedMin),
  );

  /// How many of the window's nights met the reference.
  int get onTarget => nights.where((night) => night.totalMin >= kSleepNeedMin).length;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return InstrumentModule(
      label: 'Sleep debt · last 7 nights',
      tag: null,
      minHeight: 0,
      trailing: Text(
        '$onTarget/${nights.length} on target',
        style: HType.number(colors.ink3, size: 10, weight: FontWeight.w400),
      ),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              hoursMinutes(shortfallMin.round()),
              style: HType.number(hues.heart, size: 28),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'shortfall vs 8h',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HType.number(colors.ink3, size: 12, weight: FontWeight.w400),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _chartHeight,
          child: HDebtBars(
            totalsMin: <double>[for (final night in nights) night.totalMin],
            labels: <String>[for (final night in nights) night.label],
            needMin: kSleepNeedMin.round(),
            progress: progress,
            height: _chartHeight,
          ),
        ),
        const SizedBox(height: 10),
        SleepLegend(<LegendKey>[
          LegendKey(colors.fav, 'Met 8h'),
          LegendKey(hues.heart, 'Short'),
          LegendKey.dashed(hues.heart, '8h target'),
        ]),
      ],
    );
  }
}
