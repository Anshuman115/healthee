/// The full reading of one suggestion — the reference design's detail sheet.
///
/// `design_reference` shows a challenge opening into **five** blocks: the
/// commitment itself, `TARGET`, `HOW TO DO IT`, `WHY THIS` and `PAYOFF`, with a
/// sticky accept control under them. The app was drawing two of those — a title
/// and the why — and dropping the rest on the floor.
///
/// ## Everything here was already on the wire
///
/// `Challenge` has carried `how_to`, `expected_outcome`, `difficulty`,
/// `comparator`, `target`, `cadence` and `window_days` since the endpoint
/// existed. This is the fourth surface this session where the server wrote the
/// honest, specific thing and the client discarded it — after `fitness_plan`,
/// `zone_minutes` and the generation `rejected` reasons.
///
/// ## ⛔ Two things the reference does that this may not
///
/// **No citation chips.** The reference prints `mvpa minutes mortality` and
/// `exercise mortality` as pills under the why. The owner asked for reference
/// pills gone from every surface, twice, and `citation_sweep_test.dart` is now
/// a gate on it. The sources reach the ⓘ instead, which is where every other
/// screen in this app keeps them.
///
/// **No raw markers.** The reference's payoff line ends `…daytime alertness
/// [sleep_need_debt].` Every string here goes through `GroundedProse`, which is
/// the bug that was fixed on the card an hour ago.
///
/// ## The typefaces are not copied either
///
/// The reference is set in a serif display face and a monospace for the target.
/// `instrument_type.dart` argues the app down to one face on purpose and names
/// `FontFeature.tabularFigures` as what replaces the mono texture. So the target
/// strip is tracked and tabular rather than monospaced, and the headings take
/// the app's own tiny caps.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/features/actions/v02/deck_item.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:solar_icons/solar_icons.dart';

/// Opens [item] in full.
Future<void> showChallengeSheet(
  BuildContext context,
  DeckItem item, {
  required VoidCallback onAdopt,
}) => showAppSheet<void>(
  context: context,
  builder: (context) => _ChallengeSheet(item: item, onAdopt: onAdopt),
);

class _ChallengeSheet extends StatelessWidget {
  const _ChallengeSheet({required this.item, required this.onAdopt});

  static const double blockGap = 12;

  final DeckItem item;
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ToneScope(
      tone: item.tone,
      child: Builder(
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Radii.sheet),
            ),
            border: Border.all(color: colors.line),
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            10,
            18,
            18 + sheetBottomInset(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 14),
              Flexible(child: SingleChildScrollView(child: _body(context))),
              if (!item.adopted && item.adopt != null) ...<Widget>[
                const SizedBox(height: 14),
                HButton(
                  kind: HButtonKind.family,
                  label: 'Accept challenge',
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAdopt();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (item.meta case final String category)
              CategoryChip(label: category),
            if (item.difficulty case final String hard) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                hard,
                style: TypeScale.tinyLabel.copyWith(
                  color: colors.ink3,
                  letterSpacing: 1,
                ),
              ),
            ],
            const Spacer(),
            MetricInfoDot(
              null,
              detail: MetricDetail.grounded(
                item.grounding,
                title: item.plainTitle,
              ),
              fallbackTitle: item.plainTitle,
            ),
          ],
        ),
        const SizedBox(height: 10),
        GroundedProse(
          text: item.title,
          style: HType.serif(colors.ink, size: 21),
        ),
        if (item.targetLine case final String target) ...<Widget>[
          const SizedBox(height: blockGap),
          TargetStrip(target: target, window: item.window),
        ],
        if (item.howTo case final String how) ...<Widget>[
          const SizedBox(height: blockGap),
          _Block(label: 'HOW TO DO IT', body: how),
        ],
        if (item.rationale case final String why) ...<Widget>[
          const SizedBox(height: blockGap),
          _Block(label: 'WHY THIS', body: why),
        ],
        if (item.payoff case final String payoff) ...<Widget>[
          const SizedBox(height: blockGap),
          _Block(
            label: 'PAYOFF',
            body: payoff,
            icon: SolarIconsOutline.cupStar,
          ),
        ],
      ],
    );
  }
}

/// `≥ 380 min sleep · daily` with its window — the commitment, set apart.
class TargetStrip extends StatelessWidget {
  /// Builds the strip.
  const TargetStrip({required this.target, this.window, this.dense = false, super.key});

  /// The commitment, already worded by [DeckItem].
  final String target;

  /// `7-day`, drawn on the right. Null draws nothing.
  final String? window;

  /// The card's tighter form.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final family = context.family;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 12,
        vertical: dense ? 6 : 10,
      ),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: hSquircle(
          12,
          side: BorderSide(color: colors.line, width: hairline),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(SolarIconsOutline.flag, size: dense ? 13 : 15, color: family),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Tracked and tabular, which `instrument_type.dart` names as what
              // replaced the monospace face the reference uses here.
              style: (dense ? TypeScale.tinyLabel : TypeScale.panelContext)
                  .copyWith(
                    color: family,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
          if (window case final String run) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              run,
              style: TypeScale.tinyLabel.copyWith(color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// One labelled block of the sheet.
class _Block extends StatelessWidget {
  const _Block({required this.label, required this.body, this.icon});

  final String label;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: colors.surface,
        // 12 is the floor `project_app_visual_language` sets for the corner,
        // not below it — at 12 and above the app draws a superellipse.
        shape: hSquircle(12, side: BorderSide(color: colors.line, width: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label,
                style: TypeScale.tinyLabel.copyWith(
                  color: colors.ink3,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Icon(
                icon ?? SolarIconsBold.record,
                size: icon == null ? 7 : 14,
                color: context.family,
              ),
            ],
          ),
          const SizedBox(height: 7),
          GroundedProse(
            text: body,
            style: TypeScale.panelContext.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

/// The category pill — `SLEEP`, `ACTIVITY`, in the family's own soft ground.
class CategoryChip extends StatelessWidget {
  /// Builds the chip.
  const CategoryChip({required this.label, this.tinted = true, super.key});

  /// The category, already uppercased.
  final String label;

  /// Whether it carries the family's soft ground.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final family = context.family;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tinted ? context.familySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TypeScale.tinyLabel.copyWith(
            color: family,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}
