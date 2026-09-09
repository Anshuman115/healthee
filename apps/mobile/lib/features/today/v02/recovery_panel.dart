/// `Recovery, explained` — the number, how the model divides, and its four bars.
///
/// `panels.js::H.recoveryPanel`, in order: the figure over 100 with the
/// overnight/remaining split beside it, the weight stack, the colour key, the
/// factor bars, and the note.
///
/// ## The components are the licence to show the number at all
///
/// `feedback_no_composite_score` is the rule and this card is the reason it
/// survives the redesign: a single 0–100 score with nothing under it is a
/// verdict, and the four bars are what turn it back into a model. They are
/// beside the number rather than behind a tap, exactly as the pre-v02 card had
/// them.
///
/// **They are the payload's factors, not a fixed four.** The prototype hard-codes
/// Sleep/HRV/Resting heart/Breathing at 40/30/20/10; a server that drops a term
/// or reweights one must show that, so the stack, the key and the bars are all
/// built from `recovery.factors` in the payload's own order. A factor with no
/// weight is left out of the stack and the key and still draws its bar — its
/// share is unknown, its score is not.
///
/// ## The framing sentence is not the server's guidance, and both are shown
///
/// `guidance` is the model's prose about today. The sentence under it is about
/// what the four bars **are** — "model components, not four additional health
/// scores" — and it is true on every payload, including the ones that carry no
/// guidance at all. Folding one into the other would lose whichever the day did
/// not happen to have.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/v02/colour_key.dart';
import 'package:healthee/shared/v02/meters.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// What the four bars ARE. Method, so it lives behind the ⓘ.
const String kRecoveryComponentsNote =
    'Model components, not four additional health scores.';

/// KEPT ON THE CARD, deliberately.
///
/// This is clinical routing, not teaching copy: it tells an owner that a symptom
/// outranks the number they are looking at. The sweep that moved method text off
/// the cards is explicitly not allowed to take a sentence like this with it —
/// deleting one to reduce clutter is the one failure that would make the screen
/// worse rather than tidier.
const String kRecoveryPriorityNote =
    'How you feel and any illness signal take priority.';

/// The family a recovery factor or signal belongs to, from its id or its name.
///
/// It matches on either, because the two carriers of the same four things are
/// named differently on the wire: `recovery_score.factors` is keyed `hrv` /
/// `rhr` / `rr` / `sleep`, and `recovery.signals` names them in words. An
/// unrecognised name takes [Tone.fitness] — the `:root` default — rather than a
/// colour picked to look distinct, because a hue that means nothing is worse
/// than a hue that means "uncategorised".
Tone recoveryFactorTone(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('sleep')) {
    return Tone.sleep;
  }
  if (lower.contains('hrv') || lower.contains('variability')) {
    return Tone.fitness;
  }
  if (lower.contains('heart') || lower.contains('rhr')) {
    return Tone.heart;
  }
  if (lower == 'rr' ||
      lower.contains('breath') ||
      lower.contains('respir') ||
      lower.contains('oxygen') ||
      lower.contains('spo')) {
    return Tone.oxygen;
  }
  return Tone.fitness;
}

/// The recovery model, opened up.
class RecoveryPanel extends StatelessWidget {
  /// [score] is the payload's block; nothing here is computed from raw samples.
  const RecoveryPanel({required this.score, this.onDetails, super.key});

  /// The prototype's title for this card.
  static const String title = 'Recovery, explained';

  /// `.weight-stack { margin: 12px 0 }`.
  static const double stackGap = 12;

  /// `.factor-bars { margin-block: 16px }`.
  static const double barsGap = 16;

  /// The model's output and its components.
  final RecoveryScore score;

  /// Opens the recovery detail screen.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final weighted = <RecoveryFactor>[
      for (final factor in score.factors)
        if (factor.weight != null) factor,
    ];
    return Panel(
      tone: Tone.recovery,
      label: 'Recovery',
      head: PanelHead(
        title: title,
        icon: SolarIconsOutline.heartPulse,
        infoKey: 'recovery_score',
        detail: MetricDetail(
          method: const <String>[kRecoveryComponentsNote],
          notes: <String>[if (score.noteId case final String id) id],
        ),
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            '${score.recovery}',
            unit: '/100',
            context_: _side(score),
          ),
          if (weighted.isNotEmpty) ...<Widget>[
            const SizedBox(height: stackGap),
            WeightStack(<WeightSegment>[
              for (final factor in weighted)
                WeightSegment(recoveryFactorTone(factor.name), factor.weight!),
            ]),
            const SizedBox(height: stackGap),
            ColourKey(<ColourKeyEntry>[
              for (final factor in weighted)
                ColourKeyEntry(
                  '${factorLabel(factor.name)} ${_share(factor.weight!)}',
                  tone: recoveryFactorTone(factor.name),
                ),
            ]),
          ],
          if (score.factors.isNotEmpty) ...<Widget>[
            const SizedBox(height: barsGap),
            FactorBars(<Factor>[
              for (final factor in score.factors)
                Factor(
                  factorLabel(factor.name),
                  factor.subScore == null ? null : factor.subScore! / 100,
                  tone: recoveryFactorTone(factor.name),
                  reading: factor.subScore?.toString(),
                ),
            ]),
          ],
          if (score.guidance case final String guidance) PanelNote(guidance),
          const PanelNote(kRecoveryPriorityNote),
        ],
      ),
    );
  }

  /// `Overnight estimate` and, when the server sent one, what is left of today.
  static String _side(RecoveryScore score) {
    const overnight = 'Overnight estimate';
    return score.readiness == null
        ? overnight
        : '$overnight\n${score.readiness} / 100 remaining';
  }

  /// `0.4` → `40%`. A weight the server sent as a percentage already is left
  /// alone: anything above 1 is read as one.
  static String _share(double weight) =>
      '${(weight <= 1 ? weight * 100 : weight).round()}%';
}
