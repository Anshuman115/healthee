/// The biological-age hero when the server refuses the number.
///
/// ## The defect
///
/// The owner, on the installed build: *"today is there the bio age and all those
/// are missing"*. It was never a data bug. `/api/today` correctly returns
/// `biological_age: null` with `data_confidence: "insufficient_data"` and a
/// `withheld` block — the weight behind the BMI term is over 14 days old, so the
/// fitness term has no current value and the composite is not computed. That
/// refusal is right and stays.
///
/// What was wrong was the drawing. The server writes that block as
/// `consequence` + `terms` with no top-level `reason`/`message`, which the
/// client's envelope read as "no withheld block at all" — so the null value fell
/// through to `Excluded`, and Today drew a small dashed hole followed by the
/// whole ~400-word regularity exclusion, inline, where the hero belongs.
/// `data/honesty/envelope.dart` fixes the parse; this file fixes the drawing.
///
/// ## A withheld hero is still a hero
///
/// Same ground, radius, padding, eyebrow and model label. What changes is only
/// what stands in the figure's place and what is said under it. Three decisions
/// were made deliberately and are recorded here because each of them could have
/// gone the other way:
///
///   * **The halo does not run.** It is decoration, not a measurement, so it is
///     allowed either way — but it is also the one thing on this card that
///     MOVES, and an ambient field turning around an absent number reads as
///     "still computing". A refusal is an answer, not a pending state. It also
///     costs 30 fps to say nothing.
///   * **The age ruler is not drawn at all** — not even with the chronological
///     age alone. The ruler exists to place the estimate AGAINST that age; with
///     no estimate, a single remaining dot on a 28–44 scale is a mark a reader
///     will take for the estimate. "Never draw a marker for a value that does
///     not exist" is enforced structurally here: there is no instrument to draw
///     a marker on.
///   * **A held value never reaches the ruler either.** [LastKnown] is not a
///     [Reading] and cannot be handed to `AgeScale`, `BioStat` or the caption
///     builder, so a stale figure cannot become a ruler mark, a contribution, a
///     delta against today, or a chart's latest point. That is the difference
///     between this and the stale-as-current failure: the value is shown, dated,
///     and fed to nothing.
///
/// ## What is said, and where the rest of it went
///
/// The card says, in two short lines, which term has no current value and where
/// the rest is. The server's own prose — the `consequence` paragraph, each
/// absent term's remedy ("Log a weight and it returns."), and the permanent
/// regularity exclusion — is the ⓘ's, which is where this screen's other
/// long-form method text already lives. The exclusion keeps a **signpost** on
/// the card naming the term, because a lever this number deliberately does not
/// price must stay visible; only its 800-character justification moves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/last_known.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/today/v02/today_hero.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/bio_hero_parts.dart';

/// Where the reader is sent for the paragraphs that used to be printed inline.
const String kWithheldPointer = 'Tap ⓘ for why, and what would bring it back.';

/// What the ⓘ calls the server's refusal prose.
const String kWithheldSheetLabel = 'WHY THERE IS NO NUMBER TODAY';

/// The refused biological-age hero, with the last value this phone held.
class TodayBioHeroWithheld extends ConsumerWidget {
  /// [withheld] is the server's own block, already parsed.
  const TodayBioHeroWithheld({
    required this.withheld,
    this.exclusions = const <Disclosure>[],
    super.key,
  });

  /// The metric's key in `kMetricInfo`.
  static const String infoKey = 'biological_age';

  /// Why there is no number, and — in its `terms` — what would bring it back.
  final Disclosure withheld;

  /// Levers this number permanently does not price. Signposted, never blamed.
  final List<Disclosure> exclusions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = context.colors.bioInk;
    // Lazy: nothing touches the 60-day tier until a hero is actually refused.
    // While the read is in flight the hero draws its no-value state, which is
    // the honest thing to show for "we do not yet know of an older one".
    final held = ref.watch(lastKnownBiologicalAgeProvider).value;
    return BioHero(
      eyebrow: TodayBioHero.eyebrow,
      eyebrowAction: MetricInfoDot(
        infoKey,
        ink: ink,
        detail: MetricDetail(
          disclosures: <Disclosure>[
            withheld,
            ...exclusions,
          ],
          disclosuresLabel: kWithheldSheetLabel,
        ),
      ),
      value: held == null ? BioWithheldFigure.noValue : figureOf(held.value),
      figure: BioWithheldFigure(
        ink: ink,
        value: held == null ? null : figureOf(held.value),
        asOf: held?.day,
      ),
      caption: caption(withheld, exclusions),
      modelLabel: kPopulationModelLabel,
      modelIcon: Icons.info_outline,
    );
  }

  /// `34.3`, and `34` when whole — [TodayBioHero]'s rule, so a held value and a
  /// current one are never formatted two different ways.
  static String figureOf(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  /// The short reason, the pointer, and the exclusion signpost.
  ///
  /// **Which sentence is short is a property of the server's two shapes, not a
  /// length heuristic.** `freshness.withheld_block` writes a single metric's
  /// refusal as one second-person remedy — *"Log a weight and it returns."* —
  /// which is exactly what belongs beside the missing number, so it is printed
  /// verbatim. A COMPOSITE's block instead carries a `consequence` (four
  /// sentences about why the whole estimate goes when any term does) over a
  /// `terms` list; that paragraph is the essay, so the card names the absent
  /// terms — a transcription of `terms[].term`, not a claim — and the paragraph
  /// and each term's own remedy go behind the ⓘ.
  static String caption(Disclosure withheld, List<Disclosure> exclusions) {
    final absent = <String>[
      for (final term in withheld.terms)
        if (term.term case final String name) name,
    ];
    final left = <String>[
      for (final exclusion in exclusions)
        if (exclusion.term case final String name) name,
    ];
    return <String>[
      if (withheld.terms.isEmpty)
        withheld.message
      else if (absent.isEmpty)
        'No estimate today: a term behind it has no current value.'
      else
        'No estimate today: no current value for ${_names(absent)}.',
      kWithheldPointer,
      if (left.isNotEmpty) 'Left out of this number: ${_names(left)}.',
    ].join('\n');
  }

  /// `a`, `a and b`, `a, b and c` — an Oxford-free list of the server's terms.
  static String _names(List<String> names) {
    if (names.length == 1) {
      return names.first;
    }
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}
