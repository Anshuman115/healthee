/// One suggestion as a **card**, in the reference design's shape.
///
/// ## ⛔ Not an accordion
///
/// It was a row with a chevron, one open at a time. The reference design lays
/// every suggestion out in full — category and difficulty, the title, the
/// commitment, why it is being offered, what it is expected to buy, and the
/// control — and does not make the reader open anything to see what is on
/// offer. A fold here made the owner click to find out what each card even was.
///
/// Depth beyond that still lives in the sheet (`HOW TO DO IT`, the sources),
/// because a card carrying every block of the reference's detail view is the
/// oversized card this screen has been pulled back from twice.
///
/// Split out of `suggestion_list.dart` at the 400-line limit. The division is
/// the honest one: that file decides WHICH suggestions exist and how the screen
/// stands overall; this decides what one of them looks like open and shut.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/api/problem_message.dart';
import 'package:healthee/features/actions/v02/challenge_sheet.dart';
import 'package:healthee/features/actions/v02/deck_item.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/surface_cards.dart';
import 'package:solar_icons/solar_icons.dart';

/// One suggestion: a row that opens into its reasoning and its control.
class SuggestionRow extends StatefulWidget {
  /// Builds the card.
  const SuggestionRow({required this.item, super.key});

  /// What it offers.
  final DeckItem item;

  /// The gap between blocks inside the card.
  static const double blockGap = 9;

  @override
  State<SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends State<SuggestionRow> {
  bool _busy = false;
  String? _trouble;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ToneScope(
      tone: item.tone,
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          final family = context.family;
          return PlainCard(
            inset: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // **`Expanded`, and no `Spacer`.** A loose `Flexible` beside
                    // a `Spacer` makes two flex children of one row: they split
                    // the free space between them and the `Flexible` keeps its
                    // unused half as slack, which stranded the ⓘ three quarters
                    // of the way across instead of at the margin. Third time
                    // this trap has been hit on this project — the chip group
                    // takes the remainder, the dot is intrinsic beside it.
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (item.meta case final String category)
                            Flexible(child: CategoryChip(label: category)),
                          if (item.difficulty case final String hard) ...<Widget>[
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                hard,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypeScale.tinyLabel.copyWith(
                                  color: colors.ink3,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    HTap(
                      onTap: () => showChallengeSheet(
                        context,
                        item,
                        onAdopt: () => unawaited(_take(item)),
                      ),
                      semanticLabel: 'Full detail',
                      child: Icon(
                        SolarIconsOutline.infoCircle,
                        size: 16,
                        color: colors.ink3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SuggestionRow.blockGap),
                GroundedProse(
                  text: item.title,
                  style: HType.serif(colors.ink, size: 15),
                ),
                if (item.targetLine case final String target) ...<Widget>[
                  const SizedBox(height: SuggestionRow.blockGap),
                  TargetStrip(
                    target: target,
                    window: item.window,
                    dense: true,
                  ),
                ],
                if (item.body case final String why) ...<Widget>[
                  const SizedBox(height: SuggestionRow.blockGap),
                  GroundedProse(
                    text: why,
                    // Clamped: the reference runs the whole paragraph, and four
                    // of those is the wall this screen keeps becoming. The rest
                    // is one tap away in the sheet.
                    maxLines: 3,
                    style: TypeScale.panelNote.copyWith(color: colors.ink2),
                  ),
                ],
                if (item.payoff case final String payoff) ...<Widget>[
                  const SizedBox(height: SuggestionRow.blockGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(SolarIconsOutline.cupStar, size: 13, color: family),
                      const SizedBox(width: 7),
                      Expanded(
                        child: GroundedProse(
                          text: payoff,
                          maxLines: 2,
                          style: TypeScale.panelNote.copyWith(
                            color: colors.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.raisedBy case final String line
                    when item.targetLine == null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    line,
                    style: TypeScale.tinyLabel.copyWith(color: colors.ink3),
                  ),
                ],
                const SizedBox(height: 11),
                if (item.adopted)
                  const PanelNote('You said yes to this.')
                else
                  HButton(
                    // The card's own family, so the control is the same colour
                    // as the chip that said what this is about.
                    kind: HButtonKind.family,
                    label: _busy ? 'Saving…' : _acceptLabel(item),
                    onPressed: _busy || item.adopt == null
                        ? null
                        : () => unawaited(_take(item)),
                  ),
                if (_trouble case final String message) ...<Widget>[
                  const SizedBox(height: 8),
                  Semantics(liveRegion: true, child: PanelNote(message)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// The reference's own wording, and it differs by horizon: a challenge is
  /// accepted, a suggestion for today is simply taken.
  static String _acceptLabel(DeckItem item) =>
      item.targetLine == null ? 'I’ll try this' : 'Accept challenge';

  Future<void> _take(DeckItem item) async {
    setState(() {
      _busy = true;
      _trouble = null;
    });
    try {
      await item.adopt!();
    } on Exception catch (error, stack) {
      AppLog.failure('actions', 'recording an intention', error, stack);
      if (mounted) setState(() => _trouble = apiProblem(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
