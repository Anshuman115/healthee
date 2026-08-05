/// Recovery and readiness, as legacy's headline instrument.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:688` —
/// `_RecoveryCard`. Anatomy unchanged:
///
/// ```text
///   RECOVERY                                        ●
///     ╭────╮      Recovered
///     │ 62 │      Morning recovery 72 · −10 from today's strain
///     ╰────╯
///   ┌────────────────────────────────────────────────┐
///   │ 🏋  An illness signal is active — it overrides …│  the guidance block
///   └────────────────────────────────────────────────┘
///   HRV        ▬▬▬▬▬▬▭▭▭▭   48 · base 45
///   Resting HR ▬▬▬▬▬▭▭▭▭▭   55 · base 55
///   Sleep      ▬▬▬▬▭▭▭▭▭▭   6.3h / 8h
///   Breathing  ▬▬▬▬▬▬▭▭▭▭   14 · base 14
///   Estimate from your overnight HRV & resting HR vs your baseline, …
/// ```
///
/// The gauge shows **readiness** and the sentence beside it shows morning
/// recovery, which is legacy's split and is the honest one: readiness is
/// recovery decayed by strain already spent, so showing only the first would
/// hide the day's cost and showing only the second would overstate what is left.
///
/// ## The breakdown is the licence, not a detail panel
///
/// `docs/APP_DESIGN.md` §1 approves this composite **because** it always renders
/// its per-factor breakdown, and `feedback_no_composite_score` is the standing
/// rule behind that. Legacy's layout happens to satisfy it: the factor rows take
/// more of the card than the number does.
///
/// A factor with no sub-score keeps its row and draws an empty bar rather than
/// being dropped — `derive/recovery.py` only writes a factor it could score, so
/// the row is present exactly when the signal was measured.
///
/// ## Where legacy's ⓘ went
///
/// Legacy's `infoKey: 'recovery_score'` draws an ⓘ opening `metric_info.dart`'s
/// explainer sheet. That sheet is not in this rebuild, so the control is not
/// drawn — but the note it names still is, as a citation chip resolving to the
/// corpus's own title. Losing the control is a port gap; losing the grounding
/// would be an honesty regression, and the two are not the same thing.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/charts/h_tick_gauge.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:solar_icons/solar_icons.dart';

/// The recovery gauge, the guidance, and the four factor rows.
class RecoveryCard extends StatelessWidget {
  /// [reveals] must be the screen's registry, not one built here.
  const RecoveryCard({required this.score, required this.reveals, super.key});

  /// The day's recovery, readiness, band, guidance and factors.
  final RecoveryScore score;

  /// Where "this gauge has already animated" is remembered.
  final RevealRegistry reveals;

  /// Legacy's factor order (`today_screen.dart:704`). Not the payload's — a map
  /// has no order, and two renders of the same day must read the same way.
  static const List<String> factorOrder = <String>['hrv', 'rhr', 'sleep', 'rr'];

  /// The closing sentence, legacy's verbatim.
  static const String method =
      'Estimate from your overnight HRV & resting HR vs your baseline, sleep vs '
      'need, and breathing — weighted by evidence, shown in full. Trend matters '
      'more than one day.';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final readiness = score.readiness ?? score.recovery;
    // Legacy's band → colour and band → word, both defaulting to `moderate`.
    final band = score.band ?? 'moderate';
    final tint = switch (band) {
      'high' => colors.accent,
      'low' => colors.alert,
      _ => hues.calories,
    };
    final word = switch (band) {
      'high' => 'Recovered',
      'low' => 'Run down',
      _ => 'Moderate',
    };
    final drained = readiness < score.recovery;
    return InstrumentModule(
      label: 'Recovery',
      tag: tint,
      minHeight: 0,
      children: [
        RevealOnce(
          id: 'today.recovery',
          registry: reveals,
          builder: (context, t) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HTickGauge(
                    value: readiness.toDouble(),
                    size: 116,
                    color: tint,
                    progress: t,
                    child: _GaugeCentre(readiness: readiness),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(word, style: HType.serif(tint, size: 19)),
                        const SizedBox(height: 4),
                        Text(
                          drained
                              ? 'Morning recovery ${score.recovery} · '
                                    '−${score.recovery - readiness} from '
                                    "today's strain"
                              : 'Morning recovery ${score.recovery}',
                          style: HType.sans(colors.ink3, size: 12, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (score.guidance case final String guidance
                  when guidance.isNotEmpty) ...[
                const SizedBox(height: 13),
                _Guidance(text: guidance, tint: tint),
              ],
              const SizedBox(height: 14),
              for (final name in factorOrder)
                if (_factor(name) case final RecoveryFactor factor)
                  _FactorRow(factor: factor, progress: t),
              const SizedBox(height: 12),
              Text(
                method,
                style: HType.sans(colors.ink3, size: 10.5, height: 1.4),
              ),
              // Legacy names its source with an ⓘ opening `metric_info.dart`'s
              // explainer sheet, which this rebuild does not have. The note is
              // still named, as a chip resolving to the corpus's own title —
              // that is the honesty half of the same control, and dropping it
              // would leave the one composite on this screen ungrounded.
              if (score.noteId case final String note) ...[
                const SizedBox(height: 10),
                CitationRow(noteIds: [note]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  RecoveryFactor? _factor(String name) {
    for (final factor in score.factors) {
      if (factor.name == name) {
        return factor;
      }
    }
    return null;
  }
}

/// The figure inside the arc, and the word under it.
class _GaugeCentre extends StatelessWidget {
  const _GaugeCentre({required this.readiness});

  final int readiness;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Legacy's 74 px box and `FittedBox`: a three-digit readiness must
        // shrink rather than overflow the arc.
        SizedBox(
          width: 74,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$readiness',
              style: HType.number(colors.ink, size: 36),
            ),
          ),
        ),
        Text(
          'READY',
          style: HType.label(colors.ink3, size: 9, tracking: 0.16),
        ),
      ],
    );
  }
}

/// The tinted block carrying the server's deterministic guidance sentence.
///
/// Rendered **verbatim**: an active illness flag overrides this text on the
/// server (`read/recovery.py:75`), and an app that re-worded it would re-word a
/// safety message.
class _Guidance extends StatelessWidget {
  const _Guidance({required this.text, required this.tint});

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: ShapeDecoration(
        color: tint.withValues(alpha: 0.09),
        shape: hSquircle(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HIconBadge(
            SolarIconsBold.dumbbellSmall,
            color: tint,
            size: 30,
            radius: 10,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: HType.sans(
                colors.ink,
                size: 12.5,
                height: 1.4,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `HRV  ▬▬▬▬▭▭  48 · base 45` — legacy's factor row.
class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor, required this.progress});

  final RecoveryFactor factor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final sub = (factor.subScore ?? 50).clamp(0, 100).toDouble();
    // Legacy's three bands. A sub-score IS a judgement about the owner, which is
    // the one thing colour is licensed for here.
    final bar = sub >= 60
        ? colors.accent
        : sub >= 40
        ? hues.calories
        : colors.alert;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              factorLabel(factor.name),
              style: HType.sans(colors.ink2, size: 12.5),
            ),
          ),
          Expanded(
            child: HProgressBar(
              value: sub,
              progress: progress,
              height: 5,
              color: bar,
              semanticLabel: '${factorLabel(factor.name)} ${sub.round()} of 100',
            ),
          ),
          const SizedBox(width: 10),
          Text(
            factorReading(factor),
            style: HType.number(
              colors.ink3,
              size: 10.5,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner-facing name for a factor id. Legacy's `names` map.
String factorLabel(String name) => switch (name) {
  'hrv' => 'HRV',
  'rhr' => 'Resting HR',
  'rr' => 'Breathing',
  'sleep' => 'Sleep',
  _ => name,
};

/// The right-hand reading on a factor row. Legacy's `fval`.
///
/// Sleep is the odd one and legitimately so: it is scored against an absolute
/// need rather than the owner's own baseline, so it reads `6.3h / 8h` where the
/// others read `48 · base 45`. Legacy's en dash for a factor with no value is
/// kept — the row exists because the factor was scored, so this is the narrow
/// case where the score arrived without the number behind it.
String factorReading(RecoveryFactor factor) {
  if (factor.name == 'sleep') {
    final slept = factor.tstMin;
    final need = factor.needMin;
    // **A repaired flaw.** Legacy defaults the pair to `0` and `480`, so a
    // payload that scored the factor without sending its minutes prints
    // `0.0h / 8h` — a claim that the owner slept nothing. The row already says
    // the factor WAS scored; what is missing is the reading behind it, and the
    // en dash is what the other three factors already use for exactly that.
    if (slept == null || need == null) {
      return '–';
    }
    return '${decimalHours(slept)} / ${(need / 60).round()}h';
  }
  final value = factor.value;
  if (value == null) {
    return '–';
  }
  final baseline = factor.baseline;
  return baseline == null
      ? '${value.round()}'
      : '${value.round()} · base ${baseline.round()}';
}
