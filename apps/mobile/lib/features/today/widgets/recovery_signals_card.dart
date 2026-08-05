/// The recovery **signal ladder** — legacy's per-marker readout.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:788` —
/// `_RecoverySignals`. Anatomy unchanged: the tally on the right of the header,
/// a 5 px dot strip with one segment per marker, then one row per marker
/// (arrow chip · name · value, then the comparison phrase and the source in
/// italic), and the closing sentence about why there is no composite.
///
/// ```text
///   RECOVERY SIGNALS                       1 of 1 favorable
///   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬
///   ↑  Sleep duration                              6h 20m
///      at or above your usual (6h 20m) · Sleep duration & mortality
///   Each marker is research-backed and compared to your own baseline. …
/// ```
///
/// ## Two things that stay the server's, deliberately
///
/// **Direction.** Which side of a baseline is favourable is a research question
/// — a low resting heart rate is good, a low HRV is not — so the colour comes
/// from `signal.direction` and is never re-derived from the sign of `z`.
///
/// **The tally denominator.** `RecoverySignals.total` is the server's own count
/// (`today_screen.dart:795` reads `rec['total']`), not `signals.length`.
///
/// ## The one honesty change
///
/// Legacy resolves a `research_note_id` through a **three-entry map**
/// (`_recNote`, line 600) and prints an empty string for anything else, so a new
/// note cites as nothing at all. This resolves through
/// `shared/format/note_names.dart`, which is generated from the corpus manifest
/// and covers every note and alias. An id with no entry keeps its id rather than
/// vanishing — a citation we cannot name is a visible oddity, and silently
/// dropping it is the app deleting a claim's grounding.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/format/note_names.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:solar_icons/solar_icons.dart';

/// The ladder, its tally and its closing sentence.
class RecoverySignalsCard extends StatelessWidget {
  /// [signals] is the whole `recovery` block.
  const RecoverySignalsCard({required this.signals, super.key});

  /// The markers, the tallies and the summary.
  final RecoverySignals signals;

  /// Legacy's closing sentence, verbatim.
  static const String noComposite =
      'Each marker is research-backed and compared to your own baseline. No '
      'single composite score — the evidence supports the markers, not a '
      'formula.';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InstrumentModule(
      label: 'Recovery signals',
      infoKey: 'recovery',
      tag: colors.accent,
      minHeight: 0,
      trailing: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${signals.favorable}',
              style: HType.number(
                colors.ink,
                size: 11,
                weight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: ' of ${signals.total} favorable',
              style: HType.number(
                colors.ink3,
                size: 11,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < signals.signals.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: directionColor(context, signals.signals[i].direction),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        for (final signal in signals.signals) _SignalRow(signal: signal),
        const SizedBox(height: 2),
        Text(
          noComposite,
          style: HType.sans(colors.ink3, size: 12, height: 1.5),
        ),
      ],
    );
  }
}

/// Legacy's `dcol` — favourable green, neutral ink3, unfavourable heart-red.
///
/// **One repaired flaw.** Legacy's `else` branch swallows *anything that is not
/// `favorable` or `neutral`* into unfavourable — including a marker the server
/// sent no direction for at all, and any direction a later server grows. That
/// paints a verdict against the owner out of a value the app did not recognise,
/// which is the opposite of a refusal. `unfavorable` now has to say so; anything
/// else is drawn in the neutral ink that claims nothing.
Color directionColor(BuildContext context, String? direction) {
  final colors = context.colors;
  return switch (direction) {
    'favorable' => colors.accent,
    'unfavorable' => colors.alert,
    _ => colors.ink3,
  };
}

/// One marker: the arrow chip, the name, the reading, and the comparison.
class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});

  final RecoverySignal signal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = directionColor(context, signal.direction);
    final icon = switch (signal.direction) {
      'favorable' => SolarIconsBold.arrowUp,
      // Same repair as [directionColor]: an arrow is a claim about a direction,
      // and an unrecognised direction has none. It gets the level arrow.
      'unfavorable' => SolarIconsBold.arrowDown,
      _ => SolarIconsOutline.arrowRight,
    };
    final source = signal.researchNoteId == null
        ? ''
        : noteName(signal.researchNoteId!) ?? signal.researchNoteId!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  signal.name,
                  style: HType.sans(
                    colors.ink,
                    size: 14.5,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                signalReading(signal.value, signal.unit),
                style: HType.number(colors.ink, size: 13),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 3),
            child: Text.rich(
              TextSpan(
                style: HType.sans(colors.ink3, size: 11.5, height: 1.3),
                children: [
                  TextSpan(
                    text:
                        '${comparisonPhrase(signal.name, signal.direction)} '
                        '(${signalReading(signal.baseline, signal.unit)})'
                        '${source.isEmpty ? '' : ' · '}',
                  ),
                  if (source.isNotEmpty)
                    TextSpan(
                      text: source,
                      // Upright, and always was — Manrope ships no italic.
                      // See `instrument_type.dart`.
                      style: HType.sans(colors.ink3, size: 11.5),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `6h 20m` for a duration, `55 bpm` otherwise. Legacy's `fmt`.
String signalReading(double? value, String? unit) {
  if (value == null) {
    return '—';
  }
  if (unit == 'min') {
    return hoursMinutes(value);
  }
  return '${value.round()} ${unit ?? ''}';
}

/// How a marker sits against its own baseline. Legacy's `_recPhrase` (595).
///
/// A per-marker wording table with a general fallback, kept verbatim including
/// the fallback — `'vs your median'` is what an unknown marker gets, and it
/// claims no direction, which is right.
String comparisonPhrase(String name, String? direction) {
  const phrases = <String, Map<String, String>>{
    'Resting HR': {
      'favorable': 'below your median',
      'unfavorable': 'above your median',
      'neutral': 'near your median',
    },
    'Sleep duration': {
      'favorable': 'at or above your usual',
      'unfavorable': 'below your usual',
      'neutral': 'near your usual',
    },
    'Overnight HRV': {
      'favorable': 'above your median',
      'unfavorable': 'below your median',
      'neutral': 'near your median',
    },
  };
  return phrases[name]?[direction] ?? 'vs your median';
}
