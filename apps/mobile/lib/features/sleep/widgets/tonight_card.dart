/// Tonight — the one lever the server picked, its target time, and the coaching.
///
/// **Legacy** `sleep_screen.dart:709` (`_SleepTonightCard`). The lever's title at
/// `serif(ink, 18)`, the target clock at `num(cSleep, 26, w700)` over its LIGHTS
/// OUT / TARGET WAKE caption, the coaching line behind a magic-stick icon, the
/// adherence bar with `hit N of M nights`, and the nap note in a tinted block.
///
/// ## The honesty change
///
/// Legacy stripped `[[note_id]]` markers with a regex and threw them away:
/// `raw.replaceAll(RegExp(r'\[\[[^\]]+\]\]'), '')`. The coaching sentence is
/// LLM-authored and those markers are its grounding, so legacy showed the claim
/// and deleted the sources. It goes through [GroundedProse] here — the raw string
/// in, the sentence and its named sources out, with no way to ask for one without
/// the other.
///
/// The card is drawn only when the server sent a lever, which is legacy's
/// behaviour. `tonight` is stripped for a non-premium owner by `api/gate.py`, so
/// its absence is an entitlement fact rather than a missing measurement — there
/// is nothing withheld to explain.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:solar_icons/solar_icons.dart';

/// Legacy's "Tonight" module.
class TonightCard extends StatelessWidget {
  /// [lever] is the server's pick for tonight.
  const TonightCard({required this.lever, required this.progress, super.key});

  /// What to change tonight, and by how much.
  final TonightLever lever;

  /// How far the reveal has run.
  final double progress;

  /// Legacy's caption rule: a bedtime or duration lever aims at lights-out, a
  /// wake lever aims at the morning.
  String get targetCaption =>
      lever.lever == 'bedtime' || lever.lever == 'duration'
      ? 'LIGHTS OUT'
      : 'TARGET WAKE';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return InstrumentModule(
      label: 'Tonight',
      tag: hues.sleep,
      infoKey: 'sleep_consistency',
      minHeight: 0,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(lever.title, style: HType.serif(colors.ink, size: 18)),
            ),
            if (lever.targetClock case final String target) ...<Widget>[
              const SizedBox(width: 14),
              Column(
                children: <Widget>[
                  Text(target, style: HType.number(hues.sleep, size: 26)),
                  Text(
                    targetCaption,
                    style: HType.sans(colors.ink3, size: 8, weight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(SolarIconsBold.magicStick, size: 14, color: hues.sleep),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GroundedProse(
                text: lever.prose,
                style: HType.sans(colors.ink2, size: 13, height: 1.45),
              ),
            ),
          ],
        ),
        if (lever.hasAdherence) ...<Widget>[
          const SizedBox(height: 13),
          _Adherence(hit: lever.hit!, of: lever.of!, progress: progress),
        ],
        if (lever.napNote case final String note) ...<Widget>[
          const SizedBox(height: 12),
          _NapNote(note: note),
        ],
      ],
    );
  }
}

class _Adherence extends StatelessWidget {
  const _Adherence({required this.hit, required this.of, required this.progress});

  final int hit;
  final int of;
  final double progress;

  /// Legacy's two thresholds for the bar's colour.
  static const double _good = 0.6;
  static const double _fair = 0.3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final share = hit / of;
    return Row(
      children: <Widget>[
        Expanded(
          child: HProgressBar(
            value: hit.toDouble(),
            max: of.toDouble(),
            progress: progress,
            height: 5,
            color: share >= _good
                ? colors.fav
                : share >= _fair
                ? hues.movement
                : hues.heart,
            semanticLabel: 'Hit the target on $hit of $of nights',
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'hit $hit of $of nights',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HType.number(colors.ink3, size: 10.5, weight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _NapNote extends StatelessWidget {
  const _NapNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: hues.sleep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(SolarIconsBold.moonSleep, size: 14, color: hues.sleep),
          const SizedBox(width: 8),
          Expanded(
            child: GroundedProse(
              text: note,
              style: HType.sans(colors.ink2, size: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
