/// The screen's centrepiece and the three tiles under it.
///
/// `panels.js::H.bioHero` in order: the eyebrow, the halo with the figure inside
/// it, the sentence about the delta, the 28–44 ruler, a full-bleed rule, the two
/// contributions, and the model label. `screens-overview.js::summaryTiles` then
/// puts recovery, sleep and movement across one row.
///
/// ## Everything here is the server's, and an absence stays an absence
///
/// The figure is `biological_age.biological_age`; the sentence is built from
/// `delta_years` and `chronological_age` and is **omitted entirely** when either
/// is null, rather than saying "0.0 years below" about an age nothing compared.
/// The two contributions are `contributions[]`, in the payload's own order, with
/// the payload's own terms — not a fixed Fitness/Sleep pair, because a model
/// that stops sending a term must stop showing it.
///
/// The model label is the server's `disclaimer` when it sent one. The fallback
/// is the prototype's own line, which is a statement about the method rather
/// than about the owner, so it is safe to print unconditionally.
///
/// ## The tiles' meters, and when there is no meter
///
/// A tile draws `.tile-meter` only when the payload carries the reference the
/// proportion is against — sleep need for sleep, 100 for a 0–100 score. Steps
/// have no target on `/api/today`, so the movement tile draws **no meter at
/// all** rather than a bar against a number this app invented.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/features/today/steps_plateau.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/bio_hero_parts.dart';
import 'package:healthee/shared/v02/instruments/age_scale.dart';
import 'package:healthee/shared/v02/instruments/bio_halo.dart';
import 'package:healthee/shared/v02/summary_tile.dart';
import 'package:solar_icons/solar_icons.dart';

/// What the prototype prints under the age when the server sent no disclaimer.
const String kPopulationModelLabel =
    'Population-based model · not a clinical age';

/// The biological-age hero, with the halo around the figure.
///
/// Nothing here holds state. A hand pause shipped beside the arrow for a while,
/// on the strength of the prototype's README; the owner looked at it on the
/// device and asked for it to go. The field's three automatic stops — offscreen,
/// backgrounded, reduced motion — are not a preference and are the field's own.
class TodayBioHero extends StatelessWidget {
  /// [age] is the payload's block; nothing here is computed.
  const TodayBioHero({
    required this.age,
    required this.reveals,
    this.onOpenBody,
    this.onOpenTerm,
    super.key,
  });

  /// The prototype's eyebrow for this card.
  static const String eyebrow = 'Biological age · estimate';

  /// The prototype's own `aria-label` on the eyebrow's anchor.
  static const String eyebrowSemantics = 'Understand your biological age';

  /// The estimate and everything the server said about it.
  final BiologicalAge age;

  /// Where "this instrument has already revealed" is remembered.
  final RevealRegistry reveals;

  /// `<a href="#body">` on the eyebrow's arrow — the calculation behind the
  /// figure.
  final VoidCallback? onOpenBody;

  /// Where one contribution row goes, by its `term`.
  ///
  /// `.bio-bottom` is two anchors in the prototype — `#fitness` and `#sleep` —
  /// and the term decides which. Passing the term rather than two callbacks is
  /// what keeps the hero honest about a model that adds a third one: the host
  /// answers for the term it is given, or does not, and the row is drawn either
  /// way.
  final void Function(String term)? onOpenTerm;

  @override
  Widget build(BuildContext context) {
    return BioHero(
      eyebrow: eyebrow,
      // The model line and any caveat go behind this, not under the figure.
      infoKey: 'biological_age',
      eyebrowIcon: SolarIconsOutline.arrowRight,
      onEyebrowTap: onOpenBody,
      eyebrowSemantics: eyebrowSemantics,
      value: _figure(age.biologicalAge),
      unit: 'years',
      caption: _caption(age),
      artFillsCard: true,
      centred: true,
      art: const BioHalo(),
      instrument: RevealOnce(
        id: 'today.bio-age-scale',
        registry: reveals,
        builder: (context, t) => AgeScale(
          estimate: age.biologicalAge,
          chronologicalAge: age.chronologicalAge,
          progress: t,
        ),
      ),
      stats: <BioStat>[
        for (final term in age.contributions)
          if (term.deltaYears case final double delta)
            BioStat(
              '${_termName(term.term)} contribution',
              _years(delta),
              onOpen: onOpenTerm == null
                  ? null
                  : () => onOpenTerm!(term.term),
            ),
      ],
      modelLabel: age.disclaimer ?? kPopulationModelLabel,
    );
  }

  /// `34.3`, and `34` when the estimate is whole. Never `34.0`.
  static String _figure(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  /// `−1.7 years` — a real minus sign, and a `+` only when there is one.
  static String _years(double delta) {
    final magnitude = delta.abs().toStringAsFixed(1);
    if (delta == 0) {
      return '0.0 years';
    }
    return '${delta < 0 ? '−' : '+'}$magnitude years';
  }

  /// `fitness` → `Fitness`; `sleep_regularity` → `Sleep regularity`.
  ///
  /// A model term is a word the server chose, not a metric id, so this is
  /// formatting rather than naming. Underscores go because a snake_case run on
  /// a health screen reads as a log line — the rule `note_names.dart` exists
  /// for, applied to the one other place an identifier reaches the surface.
  static String _termName(String term) {
    final words = term.replaceAll('_', ' ').trim();
    if (words.isEmpty) {
      return term;
    }
    return words[0].toUpperCase() + words.substring(1);
  }

  /// `1.7 years below your chronological age of 36`, or null.
  static String? _caption(BiologicalAge age) {
    final delta = age.deltaYears;
    final chronological = age.chronologicalAge;
    if (delta == null || chronological == null) {
      return null;
    }
    final magnitude = delta.abs().toStringAsFixed(1);
    final side = delta < 0 ? 'below' : 'above';
    final actual = chronological == chronological.roundToDouble()
        ? chronological.round().toString()
        : chronological.toStringAsFixed(1);
    return delta == 0
        ? 'The same as your chronological age of $actual'
        : '$magnitude years $side your chronological age of $actual';
  }
}

/// `.summary-tiles` — recovery, sleep and movement, three across.
class TodaySummaryTiles extends StatelessWidget {
  /// [facts] is the screen's one parse of the payload.
  const TodaySummaryTiles({
    required this.facts,
    this.onOpenRecovery,
    this.onOpenSleep,
    this.onOpenActivity,
    super.key,
  });

  /// `.summary-tiles { gap: 8px }`.
  static const double gap = 8;

  /// `.summary-tiles { margin-top: 12px }`.
  static const double topGap = 12;

  /// The figures, series and labels this render is built from.
  final TodayFacts facts;

  /// Where the three tiles go.
  ///
  /// `docs/V02_CONNECTIVITY.md` section 0: *"Today's entry points are three
  /// tappable hero summary rows … not the panel 'Details' links the source read
  /// suggested. The recovery row is what opens `#recovery`."*
  final VoidCallback? onOpenRecovery;
  final VoidCallback? onOpenSleep;
  final VoidCallback? onOpenActivity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _recovery()),
            const SizedBox(width: gap),
            Expanded(child: _sleep()),
            const SizedBox(width: gap),
            Expanded(child: _movement()),
          ],
        ),
      ),
    );
  }

  /// The overnight estimate over 100, with the remaining readiness under it.
  Widget _recovery() {
    final score = facts.snapshot.recovery.valueOrNull;
    if (score == null) {
      return const _TileHole(title: 'Recovery', tone: Tone.recovery);
    }
    return SummaryTile(
      title: 'Recovery',
      icon: SolarIconsOutline.heartPulse,
      tone: Tone.recovery,
      value: '${score.recovery}',
      fraction: score.recovery / 100,
      meta: _remaining(score),
      onOpen: onOpenRecovery,
    );
  }

  static String? _remaining(RecoveryScore score) =>
      score.readiness == null ? null : '${score.readiness} remaining';

  /// Last night's total, against the server's own sleep need.
  Widget _sleep() {
    final minutes = facts.sleepDurationMin.valueOrNull;
    if (minutes == null) {
      return const _TileHole(title: 'Sleep', tone: Tone.sleep);
    }
    final need = facts.snapshot.sleepDebt.valueOrNull?.needMin;
    return SummaryTile(
      title: 'Sleep',
      icon: SolarIconsOutline.moonSleep,
      tone: Tone.sleep,
      value: hoursMinutes(minutes),
      fraction: need == null || need <= 0 ? null : minutes / need,
      meta: need == null || need <= 0
          ? null
          : '${(minutes / need * 100).round()}% of ${hoursMinutes(need)} need',
      onOpen: onOpenSleep,
    );
  }

  /// Today's steps, against the age-banded plateau. See `steps_plateau.dart`
  /// for why the denominator is derived from the note rather than picked.
  Widget _movement() {
    final steps = facts.steps.valueOrNull;
    if (steps == null) {
      return const _TileHole(title: 'Movement', tone: Tone.movement);
    }
    final plateau = stepsPlateauTop(
      facts.snapshot.biologicalAge.valueOrNull?.chronologicalAge,
    );
    return SummaryTile(
      title: 'Movement',
      icon: SolarIconsOutline.walking,
      tone: Tone.movement,
      value: commaGrouped(steps.round()),
      fraction: plateau == null ? null : steps / plateau,
      // Worded like Sleep's — `70% of 8h 0m need` — because it is the same
      // shape of claim: a measured figure over a stated denominator, with the
      // denominator named so it can be argued with.
      meta: plateau == null
          ? facts.medianFootFor(TodayMetricIds.steps).toLowerCase()
          : '${(steps / plateau * 100).round()}% of ${commaGrouped(plateau)}',
      onOpen: onOpenActivity,
    );
  }
}

/// A tile with no reading: named, held at its slot, and visibly empty.
///
/// The em dash is the tile's whole content and it is deliberate. A tile is one
/// line of a three-across row and has no room for a sentence; the card the tile
/// links to carries the reason, and the row keeps its shape rather than becoming
/// two tiles wide because one reading is missing.
class _TileHole extends StatelessWidget {
  const _TileHole({required this.title, required this.tone});

  final String title;
  final Tone tone;

  @override
  Widget build(BuildContext context) =>
      SummaryTile(title: title, tone: tone, value: '—', meta: 'Not measured');
}
