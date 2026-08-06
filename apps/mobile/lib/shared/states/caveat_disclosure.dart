/// How a caveat is carried on a screen: a compact signpost, and the sheet behind
/// it.
///
/// ## The defect this file exists to fix
///
/// The owner, on the installed build: *"below the fitness card there is some
/// bullet points in raw text i dont think thats needed to be shown there"* and
/// *"Respiratory rate text is too big which makes the card too big"*. Both are the
/// same defect. `CaveatNote` used to print every disclosure in full, inline,
/// beneath whatever rendered the value — and the server's disclosures are essays:
/// the biological-age block in the committed contract snapshot carries **four of
/// them totalling ~2,780 characters** (the FRIEND-registry paragraph, the
/// measured-session paragraph, the questionnaire-conversion paragraph, and the
/// SRI exclusion). Today grew a page of prose under one card, and the Resp tile —
/// a fixed-shape grid cell — grew a 230-character sentence inside a 92 px body
/// and stopped matching the tile beside it.
///
/// `bio_age_card.dart` records that **legacy has no surface for caveats at all**,
/// so printing them in full was our addition, not the port. This file replaces the
/// carrier, not the honesty.
///
/// ## What replaced it, and the rule it must not break
///
/// A caveated value still discloses that it is caveated, in words, on the screen —
/// and the detail is still reachable, one tap away. What changed is that the
/// *detail* moved into a sheet. `docs/APP_DESIGN_BRIEF.md` §3 asked for exactly
/// this and `withheld_card.dart` used to say so while doing the opposite: *"an
/// unobtrusive marker on the number that expands — never a modal, never a badge
/// that demands attention"*.
///
/// **The failure mode is a caveat that becomes invisible, and it is worse than the
/// essay.** Two things are structural against it:
///
///   * [caveatHeadline] is the ONE sentence both carriers show and it **counts
///     the disclosures**, so dropping one changes text that is on screen rather
///     than text nobody was reading.
///   * Neither carrier can render empty. [CaveatNote] and [CaveatFoot] both assert
///     a non-empty list, because "zero caveats" is [Present]'s job and a carrier
///     that quietly draws nothing is the silence this whole layer exists to
///     prevent.
///
/// ## THE ASTERISK IS GONE — 2026-08-06
///
/// Owner, on the installed build: *"what are those * symbol in card"*. Exactly.
/// `CaveatMark` rendered a bare `*` in the module header and nothing anywhere
/// said what it meant, which **broke the rule this file's own docstring states
/// two paragraphs up**: a caveated value discloses that it is caveated *in
/// words*. An asterisk is not words. It was a glyph that could only be
/// understood by someone who had read this file.
///
/// Both carriers say it in words now, and neither is a bare glyph:
///
///   * [CaveatNote] — the signpost with a line to spare. It sits **inside** its
///     card (`caveat_scope.dart` explains why that moved too), names the state
///     and counts the disclosures.
///   * [CaveatFoot] — the fixed-height grid tile's carrier, in legacy's own foot
///     voice at the bottom of the cell: `1 CAVEAT · TAP TO READ`. A tile's body
///     is a fixed 92 px, but its foot already runs to two lines, so a second
///     short line costs the tile no height at all — which
///     `today_tiles_test.dart` measures rather than assumes.
///
/// The header is left with **one** control, the ⓘ, which is what the owner
/// already understands. Nothing in a header row is now unlabelled.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';

/// The sentence a caveated value shows without being asked, and the label a
/// screen reader gets from [CaveatFoot].
///
/// It names the state plainly — the same choice `WithheldCard` makes with the
/// word "WITHHELD" — and it **counts**. The count is not decoration: it is what
/// makes a dropped disclosure visible on the screen instead of only in the sheet
/// nobody opened.
String caveatHeadline(int count) => count == 1
    ? 'Caveated — one thing tilts this number'
    : 'Caveated — $count things tilt this number';

/// The same disclosure in the few words a fixed-height grid tile can hold.
///
/// It **counts**, for the reason [caveatHeadline] counts, and it names its own
/// affordance — a reader who has never seen this app before is told both that
/// there is something to know and how to get it. That is the whole difference
/// between this and the `*` it replaced.
String caveatFootnote(int count) =>
    count == 1 ? '1 caveat · tap to read' : '$count caveats · tap to read';

/// What the sheet is called, and the line under its title.
const String kCaveatSheetTitle = 'What tilts this number';

/// Opens the full disclosures behind a caveated value.
///
/// Through [showAppSheet] like every other sheet in this app — see its docstring
/// for why that is not optional.
Future<void> showCaveats(
  BuildContext context,
  List<Disclosure> caveats, {
  String? label,
}) async {
  if (caveats.isEmpty) {
    return;
  }
  await showAppSheet<void>(
    context: context,
    builder: (context) => _CaveatSheet(caveats: caveats, label: label),
  );
}

/// The signpost beneath a card: one line that names the state and opens the rest.
///
/// Replaces the inline essay. It is deliberately NOT tinted and NOT a badge: a
/// caveat is a note about how to read a number, not a verdict about the owner's
/// body, and `README.md`'s colour rule rations colour to judgement. The accent is
/// spent only on the word `READ`, which is the affordance — it used to be spent
/// on a bare `*` as well, and the owner could not read that.
class CaveatNote extends StatelessWidget {
  /// Renders the signpost for [caveats], which must not be empty.
  const CaveatNote({required this.caveats, this.label, super.key})
    : assert(
        caveats.length > 0,
        'A CaveatNote with no caveats renders a claim about nothing. A value '
        'with nothing attached is Present; see data/honesty/reading.dart.',
      );

  /// What tilts the value, and which way. Non-empty.
  final List<Disclosure> caveats;

  /// The metric's name, shown as the sheet's subtitle so an opened sheet says
  /// which number it is about.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: InkWell(
        onTap: () => showCaveats(context, caveats, label: label),
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Semantics(
          button: true,
          label: '${caveatHeadline(caveats.length)}. Opens the detail.',
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    caveatHeadline(caveats.length),
                    style: HType.sans(colors.ink2, size: 11.5, height: 1.4),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  'READ',
                  style: HType.label(colors.accent, tracking: 0.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The signpost a fixed-height grid tile can carry: a short counted line, in
/// legacy's own foot voice, at the bottom of the cell.
///
/// **Replaces `CaveatMark`, the bare `*` in the module header.** See the library
/// docstring for the owner report that killed it. The trade this widget makes is
/// the same one the mark made — cost the tile no height — but it pays for the
/// words rather than for a glyph:
///
///   * `ModuleFoot` already lays out to **two lines** (its docstring says why:
///     several of our feet have to name an instrument as well as a number), and
///     a tile's 92 px body has the slack for the second one. So the caveat line
///     sits under the median line and the cell is exactly as tall as its
///     neighbour, which `today_tiles_test.dart` measures.
///   * it is the tap target itself, so the tile does not need a second control
///     in a header row that has no width to spare.
class CaveatFoot extends StatelessWidget {
  /// Renders the foot line for [caveats], which must not be empty.
  const CaveatFoot({required this.caveats, this.label, this.gap = 8, super.key})
    : assert(
        caveats.length > 0,
        'A CaveatFoot with no caveats is a control that opens an empty sheet.',
      );

  /// What tilts the value. Non-empty.
  final List<Disclosure> caveats;

  /// The metric's name, for the sheet.
  final String? label;

  /// The air above it. `ModuleFoot`'s 8 when this line stands alone, and 2 when
  /// it follows a foot that has already spent it.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: GestureDetector(
        onTap: () => showCaveats(context, caveats, label: label),
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          label: '${caveatHeadline(caveats.length)}. Opens the detail.',
          child: ExcludeSemantics(
            child: Text(
              // Caps are the foot's voice; the semantic label above carries the
              // sentence as written, because several screen readers spell an
              // all-caps run out letter by letter.
              caveatFootnote(caveats.length).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HType.label(colors.accent, tracking: 0.04),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full disclosures, in the server's own words, one tap from the value.
///
/// The prose is NOT summarised, trimmed or paraphrased here. That was never the
/// problem: an 830-character explanation of what a reference cohort is worth is
/// exactly right for a reader who has asked for it, and exactly wrong printed
/// under a card nobody asked. The sheet is the place where the length is fine.
class _CaveatSheet extends StatelessWidget {
  const _CaveatSheet({required this.caveats, this.label});

  final List<Disclosure> caveats;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
        border: Border.all(color: colors.line),
      ),
      // The metric-info sheet's padding, and its gesture inset for the same
      // reason: this sheet paints over the tab bar too.
      padding: EdgeInsets.fromLTRB(22, 12, 22, 32 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (label case final String name) ...[
              _Eyebrow(name),
              const SizedBox(height: 6),
            ],
            Text(kCaveatSheetTitle, style: HType.serif(colors.ink, size: 24)),
            const SizedBox(height: 6),
            // Says the number is real. A reader who opened this because the
            // value looked suspicious must not leave thinking it was withheld.
            Text(
              'This number IS your number. These are the things that tilt it, '
              'and which way.',
              style: HType.sans(colors.ink3, size: 12.5, height: 1.45),
            ),
            const SizedBox(height: 18),
            for (final caveat in caveats) _CaveatBlock(caveat: caveat),
          ],
        ),
      ),
    );
  }
}

class _CaveatBlock extends StatelessWidget {
  const _CaveatBlock({required this.caveat});

  final Disclosure caveat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caveat.term case final String term) ...[
            _Eyebrow(term),
            const SizedBox(height: 7),
          ],
          Text(
            caveat.message,
            style: HType.sans(colors.ink, size: 14.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}

/// The sheet's uppercase eyebrow, styled from [HType] directly.
///
/// Not `ModuleLabel`: that widget lives beside `InstrumentModule`, which has to
/// import THIS file to place a [CaveatNote] in its body, and a sheet is not a
/// module anyway. `metric_info_sheet.dart` styles its own block labels the same
/// way for the same reason.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Text(
          text.toUpperCase(),
          style: HType.label(colors.ink3, tracking: 0.12),
        ),
      ),
    );
  }
}
