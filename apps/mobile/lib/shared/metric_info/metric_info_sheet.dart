/// The ⓘ in a card header, and the sheet behind it — **legacy's `HInfoDot` and
/// `showMetricInfo`, ported**.
///
/// `healthee-legacy/app/lib/ui/metric_info.dart:129`. Geometry unchanged: a 16 px
/// outline icon with 4 px of left padding in the header, and a bottom sheet with
/// a 36×5 grab handle, a 24 px display title, three labelled blocks, and the
/// grounding line at the foot.
///
/// ## It is now the ONE destination for a card's method text
///
/// The owner, on the installed v02 build: *"that reference pill can we remove
/// those from cards please info sheets are for that"*. So this sheet also
/// renders the card's OWN, payload-derived provenance — [MetricDetail]: the
/// references its figures are read against, the sources the payload cited, the
/// prose that used to sit under its chart, and any server disclosure too long to
/// print beside a number.
///
/// **Server-authored prose sends its grounding here too.** `GroundedProse` and
/// `GroundedMarkdown` used to draw a citation row under every sentence a model
/// wrote — Sleep's analysis, Actions' rationales, Insights and the coach. The
/// owner asked three times for those off the card faces; the ids, the grade, the
/// server's source sentence, the `[personal_finding:…]` markers and anything
/// that resolved to nothing all arrive here instead, on [MetricDetail].
///
/// **The dot's own gate moved with it.** It used to draw nothing for a key the
/// map does not hold, which was right when the sheet held only the static
/// explainer: an ⓘ that opens an empty sheet is worse than no ⓘ. It is wrong now
/// — a card with citations and no explainer entry (Strength is the live one)
/// would lose its grounding to a sheet nobody can open. So the dot draws when
/// there is an explainer **or** a non-empty detail, and only vanishes when there
/// is genuinely nothing behind it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/shared/format/note_grades.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';
import 'package:healthee/shared/metric_info/metric_info_blocks.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:solar_icons/solar_icons.dart';

/// What the sheet calls the references a card's figures are read against.
const String kReferenceBlockLabel = 'READ AGAINST';

/// What it calls the prose moved off the card's face.
const String kMethodBlockLabel = 'HOW TO READ IT';

/// The default heading over a withheld or excluded run of server prose.
const String kDisclosureBlockLabel = 'WHY THERE IS NO NUMBER';

/// The grounding at the foot of a sheet: sources, grade, the server's own source
/// sentence, the single-subject findings, and anything that resolved to nothing.
///
/// Public, and the reason is the one this file's docstring gives for the sheet
/// itself. The ⓘ is not the only sheet that answers *"how do we know this"* —
/// `features/actions/v02/evidence_sheet.dart` is the prototype's own
/// `H.evidence()` destination and needs the identical foot. Two hand-built
/// citation rows would be two places a claim's grounding could shrink, and the
/// one that shrank would look completely normal.
class DetailGrounding extends StatelessWidget {
  /// [noteIds] is the final, merged, de-duplicated id list; the rest of the
  /// grounding travels on [detail] so none of it can be left behind.
  const DetailGrounding({
    required this.noteIds,
    required this.detail,
    this.fallbackGrade,
    super.key,
  });

  /// The sources to name, in reading order.
  final List<String> noteIds;

  /// The card's own provenance — its grade, source sentence, personal findings
  /// and unresolved markers.
  final MetricDetail detail;

  /// The grade to show when the payload sent none.
  ///
  /// Only ever the **explainer's** own, looked up from the corpus for prose
  /// written in this repo against those notes (`shared/format/note_grades.dart`
  /// argues the distinction). Never derived from an id the payload sent.
  final String? fallbackGrade;

  @override
  Widget build(BuildContext context) => CitationRow(
    noteIds: noteIds,
    personalFindings: detail.personalFindings,
    unresolved: detail.unresolved,
    grade: detail.grade ?? fallbackGrade,
    source: detail.source,
  );
}

/// The small ⓘ button placed in a card header.
class MetricInfoDot extends StatelessWidget {
  /// [infoKey] indexes [kMetricInfo]; [detail] is the card's own provenance.
  ///
  /// An unknown (or null) key with an empty [detail] draws nothing.
  const MetricInfoDot(
    this.infoKey, {
    this.detail = MetricDetail.none,
    this.fallbackTitle,
    this.ink,
    super.key,
  });

  /// Which explainer this opens. Null for a card that has none.
  final String? infoKey;

  /// What this card carries that the static explainer cannot know.
  final MetricDetail detail;

  /// The sheet's heading when neither the explainer nor [detail] names one —
  /// a panel passes its own title.
  final String? fallbackTitle;

  /// The glyph's colour, for a card that supplies its own ink.
  ///
  /// **Not a hue a call site chose**, which is the rule this would otherwise
  /// break. The biological-age hero has its own dark surface in BOTH themes
  /// (`bioBackground`/`bioInk` are tokens for exactly that reason), so nothing
  /// drawn inside it may reach for the page's ink — the same argument
  /// `bio_hero_parts.dart` makes for the two widgets under the hero's rule.
  /// Null, everywhere else, resolves [HealtheeColors.ink3] as before.
  final Color? ink;

  /// Legacy's `Icon(..., size: 16)`.
  static const double _size = 16;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final key = infoKey;
    final info = key == null ? null : kMetricInfo[key];
    if (info == null && detail.isEmpty) {
      return const SizedBox.shrink();
    }
    final name = info?.title ?? detail.title ?? fallbackTitle ?? 'this reading';
    return GestureDetector(
      onTap: () => showMetricInfo(
        context,
        key,
        detail: detail,
        fallbackTitle: fallbackTitle,
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: Insets.xs),
        child: Semantics(
          button: true,
          label: 'What $name means, and what backs it',
          child: ExcludeSemantics(
            child: Icon(
              SolarIconsOutline.infoCircle,
              size: _size,
              color: ink ?? colors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the plain-language explainer for [key], plus whatever [detail] carries.
///
/// A no-op only when there is neither — the one case where the sheet would be
/// empty. A key the map does not hold but a card with sources still opens: the
/// sources ARE the content.
void showMetricInfo(
  BuildContext context,
  String? key, {
  MetricDetail detail = MetricDetail.none,
  String? fallbackTitle,
}) {
  final info = key == null ? null : kMetricInfo[key];
  if (info == null && detail.isEmpty) {
    return;
  }
  unawaited(
    showAppSheet<void>(
      context: context,
      builder: (context) => _MetricInfoSheet(
        info: info,
        metric: key,
        detail: detail,
        fallbackTitle: fallbackTitle,
      ),
    ),
  );
}

class _MetricInfoSheet extends StatelessWidget {
  const _MetricInfoSheet({
    required this.info,
    required this.metric,
    required this.detail,
    required this.fallbackTitle,
  });

  final MetricInfo? info;
  final String? metric;
  final MetricDetail detail;
  final String? fallbackTitle;

  /// The explainer's notes, then the card's, with no id twice.
  ///
  /// Order matters and is not alphabetical: the explainer's first note is the
  /// one a reader should open to check the headline claim, and the payload's
  /// notes are about this particular figure.
  List<String> get _notes => <String>[
    ...?info?.notes,
    for (final id in detail.notes)
      if (!(info?.notes.contains(id) ?? false)) id,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final explainer = info;
    final history = metric == null ? null : historyMetricFor(metric!);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
        border: Border.all(color: colors.line),
      ),
      // Legacy's 22/12/22/32, plus whatever the gesture bar takes. The sheet
      // now paints OVER the tab bar (`shared/sheets/app_sheet.dart`), so the
      // inset that bar used to absorb is this sheet's to leave.
      padding: EdgeInsets.fromLTRB(22, 12, 22, 32 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (history != null)
              TextButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  unawaited(
                    router.push(
                      '${Routes.history}?metric=${Uri.encodeComponent(history)}',
                    ),
                  );
                },
                child: const Text('View history and analysis'),
              ),
            Text(
              explainer?.title ?? detail.title ?? fallbackTitle ?? 'This reading',
              style: HType.serif(colors.ink, size: 24),
            ),
            const SizedBox(height: 18),
            if (explainer != null) ...<Widget>[
              InfoBlock(
                icon: SolarIconsOutline.documentText,
                label: 'WHAT IT IS',
                body: explainer.what,
                accent: colors.ink3,
              ),
              const SizedBox(height: 16),
              InfoBlock(
                icon: SolarIconsOutline.target,
                label: 'WHAT TO AIM FOR',
                body: explainer.target,
                accent: colors.accent,
              ),
              const SizedBox(height: 16),
              InfoBlock(
                icon: SolarIconsOutline.heartPulse,
                label: 'WHY IT MATTERS',
                body: explainer.why,
                accent: hues.heart,
              ),
              const SizedBox(height: 16),
            ],
            // The reference pills, off the card and kept. A cutoff with no
            // source is a number this app made up.
            if (detail.references.isNotEmpty) ...<Widget>[
              InfoLines(
                icon: SolarIconsOutline.target,
                label: kReferenceBlockLabel,
                lines: detail.references,
                accent: colors.accent,
              ),
              const SizedBox(height: 16),
            ],
            if (detail.method.isNotEmpty) ...<Widget>[
              InfoLines(
                icon: SolarIconsOutline.documentText,
                label: kMethodBlockLabel,
                lines: detail.method,
                accent: colors.ink3,
              ),
              const SizedBox(height: 16),
            ],
            if (detail.disclosures.isNotEmpty) ...<Widget>[
              DisclosureBlock(
                label: detail.disclosuresLabel ?? kDisclosureBlockLabel,
                disclosures: detail.disclosures,
                accent: colors.ink3,
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 6),
            // Legacy's grounding badge said "Grounded in peer-reviewed research,
            // not marketing scores." — over prose carrying no note id and no
            // grade. A claim of grounding is itself a claim, and it was the one
            // sentence on the sheet with nothing behind it. The sources replace
            // it: same slot, and now it is showing its working rather than
            // asserting it.
            DetailGrounding(
              noteIds: _notes,
              detail: detail,
              fallbackGrade: explainer == null
                  ? null
                  : weakestGrade(explainer.notes),
            ),
            if (explainer != null && explainer.uncited.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.sm),
              NotCoveredNote(explainer.uncited),
            ],
          ],
        ),
      ),
    );
  }
}
