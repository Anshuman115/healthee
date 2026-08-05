/// The last seven nights, stacked by stage.
///
/// **Legacy** `sleep_screen.dart:411–422`. A 120 px `HStackedSleep` with the
/// fortnight's average in the trailing slot, then the four-stage legend.
///
/// `HStackedSleep` reads `SleepNightSummary`, which is the model `/api/today`'s
/// `sleep_history_7d` already parses into. The nights on this screen come from
/// `/api/sleep`, so they are mapped across here rather than duplicating the
/// chart against a second night type — one chart, one input shape.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/features/sleep/widgets/sleep_legend.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/instrument_module.dart';

/// Legacy's "Last 7 nights" module.
class SleepWeekCard extends StatelessWidget {
  /// [nights] is **oldest first**; [averageLabel] is legacy's `avg 7h 05m`.
  const SleepWeekCard({
    required this.nights,
    required this.averageLabel,
    required this.progress,
    super.key,
  });

  /// The week, chronological.
  final List<SleepNightSummary> nights;

  /// The trailing line, already formatted, or null when there is no average.
  final String? averageLabel;

  /// How far the reveal has run.
  final double progress;

  /// Legacy's `SizedBox(height: 120)`.
  static const double _chartHeight = 120;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return InstrumentModule(
      label: 'Last 7 nights',
      tag: null,
      minHeight: 0,
      trailing: averageLabel == null
          ? null
          : Text(
              'avg $averageLabel',
              style: HType.number(colors.ink3, size: 10, weight: FontWeight.w400),
            ),
      children: <Widget>[
        SizedBox(
          height: _chartHeight,
          child: HStackedSleep(nights, progress: progress, height: _chartHeight),
        ),
        const SizedBox(height: 10),
        // Legacy's `_StageLegend`, in legacy's order and words.
        SleepLegend(<LegendKey>[
          LegendKey(hues.sleepStage('deep'), 'Deep'),
          LegendKey(hues.sleepStage('core'), 'Core'),
          LegendKey(hues.sleepStage('rem'), 'REM'),
          LegendKey(hues.sleepStage('awake'), 'Awake'),
        ]),
      ],
    );
  }
}
