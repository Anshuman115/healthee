/// Sleep debt, with the reasoning offered rather than the number asserted.
///
/// Brief §3 names the exact disclosure this card owes: *"Why debt is 120
/// minutes, not 1,400"*. It is the question anyone asks on seeing a fortnight of
/// short nights add up to two hours, and the answer is on the wire — the debt
/// model is bounded, it is not a running total of every minute ever missed.
/// Offering it inline, never as a modal, is §3's other half.
///
/// The chart is legacy's `HDebtBars`, ported: a solid bar to each night's own
/// total and a faint ghost continuing up to the need line on the nights that
/// fell short. Brief §5.4 asks for exactly that shape, because it makes "small
/// nightly shortfall, large monthly cost" visible in a way a single number never
/// does.
///
/// The nightly totals come from `sleep_history_7d`, and the label says **seven
/// nights** even though the debt window is fourteen. Drawing seven and captioning
/// it fourteen would be the same class of lie as drawing sixty days and calling
/// them ninety (brief §7.4).
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_debt.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/features/today/widgets/measured_card.dart';
import 'package:healthee/shared/charts/h_debt_bars.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/reasoning_note.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The fortnight's accumulated shortfall, with the nights behind it.
class SleepDebtCard extends StatelessWidget {
  /// [nights] is `sleep_history_7d`; it may be empty, in which case the chart
  /// is simply not drawn.
  const SleepDebtCard({
    required this.debt,
    required this.nights,
    required this.reveals,
    super.key,
  });

  /// The debt payload.
  final SleepDebt debt;

  /// The nights the chart is drawn from.
  final List<SleepNightSummary> nights;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sleep debt', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          HeroValue(value: durationLabel(debt.debtMin), unit: 'owed'),
          const SizedBox(height: Insets.xs),
          Text(_summary(debt), style: text.bodySmall?.copyWith(color: colors.ink2)),
          if (debt.lastTstWithheld) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Last night’s own total could not be established, so it is not in '
              'this window. The figure above still stands for the nights that '
              'could.',
              style: text.bodySmall?.copyWith(color: colors.ink2),
            ),
          ],
          if (nights.isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            RevealOnce(
              id: 'sleep-debt-bars',
              registry: reveals,
              builder: (context, t) => HDebtBars(
                totalsMin: [
                  for (final night in nights) night.durationMin.toDouble(),
                ],
                labels: [for (final night in nights) night.weekdayInitial],
                needMin: debt.needMin,
                progress: t,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'The last ${nights.length} nights against your '
              '${durationLabel(debt.needMin)} need. The debt above is measured '
              'over ${debt.nights}.',
              style: text.labelSmall?.copyWith(color: colors.ink3),
            ),
          ],
          const SizedBox(height: Insets.md),
          ReasoningNote(
            question:
                'Why debt is ${debt.debtMin} minutes, not '
                '${debt.nights * (debt.avgDeficitMin ?? 0)}',
            answer: _reasoning(debt),
          ),
          const SizedBox(height: Insets.sm),
          CitationRow(noteIds: debt.researchNotes),
        ],
      ),
    );
  }

  static String _summary(SleepDebt debt) {
    final parts = <String>[
      '${debt.nightsBelow} of ${debt.nights} nights below need',
      if (debt.avgTstMin case final int average)
        'averaging ${durationLabel(average)}',
      if (debt.performancePct case final int performance)
        '$performance% of need met',
    ];
    return parts.join(' · ');
  }

  /// The disclosure brief §3 asks for, built from the fields the server sent.
  static String _reasoning(SleepDebt debt) {
    return 'Debt here is what the last ${debt.nights} nights owe you, not a '
        'running total of every minute ever missed. Each night is measured '
        'against a ${durationLabel(debt.needMin)} need, the shortfalls are '
        'added up, and the window then moves on — a night from last month has '
        'already rolled out of it. Sleeping past your need does not bank '
        'credit either, which is why the figure moves down slowly and up '
        'quickly.';
  }
}
