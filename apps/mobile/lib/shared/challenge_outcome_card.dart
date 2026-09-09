/// What changed during a challenge — and the three things that stay apart.
///
/// `screens-actions.js::H.screens.outcomes` is built out of that separation and
/// so is this:
///
/// ```text
///   the reading      what the window measured, against what came before
///   the observation  "A higher average in the challenge window."
///   the caveat       "This is an observation, not a proven effect."
///   the context      illness days · concurrent challenges · regression risk
/// ```
///
/// **The intent, the observation and the causal claim are different blocks and
/// are never merged.** A challenge is an intention the owner set; the numbers are
/// what the window measured; and nothing here says the first produced the second.
/// The server refuses to say it (`confounds`, `regression_to_mean` and
/// `co_occurring` exist for exactly this) and this card refuses to imply it — the
/// closing sentence is unconditional and is not a field a payload can switch off.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';
import 'package:healthee/shared/v02/meters.dart';
import 'package:healthee/shared/v02/rows.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

/// The sentence under the comparison. Always drawn.
const String kObservationNote =
    'These are the readings inside the window, beside the readings before it. '
    'That is an observation, not a proven effect of the challenge.';

/// The closing notice's heading — the prototype's own.
const String kLearnTitle = 'A result to learn from';

/// And its body.
const String kLearnBody =
    'Keep what feels sustainable. One week can suggest a question; it cannot '
    'settle cause and effect.';

/// The heading over the confounders.
const String kContextHeading = 'The context matters';

/// One settled challenge, in the prototype's shape.
class ChallengeOutcomeCard extends StatelessWidget {
  /// [outcome] is the server's frozen result.
  const ChallengeOutcomeCard({required this.outcome, super.key});

  /// The result.
  final ChallengeOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metric = metricName(outcome.metric ?? 'this reading');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(
            '${_status(outcome.status)} · ${outcome.confidence} confidence',
            accented: true,
          ),
        ),
        // The reading. Withheld when the server settled the challenge without a
        // final value: a comparison with one end missing is not a comparison.
        if (outcome.finalValue case final double value)
          HeroReading(
            label: metric,
            value: _trim(value),
            context_: _previously(outcome),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.lg),
            child: Text(
              'The server settled this window without a final reading for '
              '$metric, so there is nothing to compare.',
              style: TypeScale.small.copyWith(color: colors.ink2),
            ),
          ),
        if (_bars(outcome) case final List<Factor> bars)
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FactorBars(bars),
                const SizedBox(height: Insets.lg),
                Text(
                  kObservationNote,
                  style: TypeScale.small.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
        if (_context(outcome) case final List<Widget> rows
            when rows.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xl),
          Text(
            kContextHeading,
            style: TypeScale.sectionTitle.copyWith(color: colors.ink),
          ),
          const SizedBox(height: Insets.md),
          RowCard(rows),
        ],
        const SizedBox(height: Insets.xl),
        const Notice(title: kLearnTitle, body: kLearnBody),
      ],
    );
  }

  /// `Previously 8,200 · 6 of 7 days met the daily target`, out of whichever of
  /// the two the server actually sent.
  static String? _previously(ChallengeOutcome outcome) {
    final parts = <String>[
      if (outcome.baseline case final double before)
        'Previously ${_trim(before)}',
      if (outcome.adherence case final double rate)
        '${(rate * 100).round()}% of days met the target',
      if (outcome.changePercent case final double change)
        'recorded change ${_trim(change)}%',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Before and during, as two bars on one scale. Null when either end is
  /// missing — half a comparison drawn as a whole one is the claim this card
  /// exists to refuse.
  static List<Factor>? _bars(ChallengeOutcome outcome) {
    final before = outcome.baseline;
    final during = outcome.finalValue;
    if (before == null || during == null) {
      return null;
    }
    final top = before > during ? before : during;
    if (top <= 0) {
      return null;
    }
    return <Factor>[
      Factor('Before', before / top, tone: Tone.movement, reading: _trim(before)),
      Factor('During', during / top, tone: Tone.movement, reading: _trim(during)),
    ];
  }

  /// The confounders the server named. Each is a fact it sent, never a default.
  static List<Widget> _context(ChallengeOutcome outcome) => <Widget>[
    if (outcome.illnessDays case final int days when days > 0)
      ListRow(
        icon: SolarIconsOutline.infoCircle,
        title: '$days illness ${days == 1 ? 'day' : 'days'}',
        subtitle: 'May affect the comparison',
        tone: Tone.heart,
      ),
    if (outcome.concurrentChallenges case final int other when other > 0)
      ListRow(
        icon: SolarIconsOutline.flag,
        title: '$other concurrent ${other == 1 ? 'challenge' : 'challenges'}',
        subtitle: 'More than one thing changed at once',
        tone: Tone.movement,
      ),
    if (outcome.regressionRisk case final bool risk)
      ListRow(
        icon: SolarIconsOutline.chart_2,
        title: risk
            ? 'Regression to the mean may explain some change'
            : 'No regression-to-mean risk was flagged',
        subtitle: 'An extreme starting point drifts back on its own',
        tone: Tone.fitness,
      ),
    if (outcome.coOccurrenceNote case final String note)
      ListRow(
        icon: SolarIconsOutline.graph,
        title: 'Something else moved too',
        subtitle: note,
        tone: Tone.stress,
      ),
  ];

  static String _status(String? status) {
    final word = status ?? 'Unreported';
    return word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
  }
}

/// Opens one outcome over the whole app.
///
/// Through [showAppSheet] and nothing else: a sheet on a branch navigator leaves
/// the tab bar live under its own scrim, and `sheet_layering_test.dart` fails the
/// build on any other presentation.
void showOutcomeSheet(BuildContext context, ChallengeOutcome outcome) {
  unawaited(
    showAppSheet<void>(
      context: context,
      builder: (context) => _OutcomeSheet(outcome: outcome),
    ),
  );
}

class _OutcomeSheet extends StatelessWidget {
  const _OutcomeSheet({required this.outcome});

  final ChallengeOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: sheetBottomInset(context)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border(top: BorderSide(color: colors.line, width: hairline)),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.lg),
            child: ChallengeOutcomeCard(outcome: outcome),
          ),
        ),
      ),
    );
  }
}

String _trim(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';
