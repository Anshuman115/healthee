/// Today's cited actions, as legacy's one collapsible block.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:896` —
/// `_ActionsSection` and `_ActionRow`. Geometry unchanged:
///
/// ```text
///   ┌──────────────────────────────────────────────┐
///   │ 💡  Suggested actions                      ›  │  15/13 padding, badge 38
///   │     3 ways to improve today                   │
///   └──────────────────────────────────────────────┘
///        ↓ tap — AnimatedSize, 280 ms, legacy's ease
///   ┌──────────────────────────────────────────────┐
///   │ ●  Sleep earlier tonight                   ›  │  8 px dot, 14 padding
///   │    ↓ tap — AnimatedSize, 220 ms               │
///   │    Debt is 120 min                            │
///   │    ┌────────────────────────────────────────┐ │
///   │    │ ⊙  Lower debt                          │ │  the sunken effect block
///   │    └────────────────────────────────────────┘ │
///   └──────────────────────────────────────────────┘
/// ```
///
/// Both levels are **collapsed by default**, which is legacy's decision and a
/// good one: the actions are the only thing on Today written by a model, and a
/// screen that opens with them puts generated prose above measurements.
///
/// ## Every string here is model prose, and none of it is printed raw
///
/// `action`, `rationale` and `expected_effect` are three of the four LLM fields
/// on `/api/today`, and they arrive with inline `[note_id]` markers. Legacy
/// printed the markers. All three go through [GroundedProse] here, which is the
/// only thing in the app that knows what a bracket means — there is no parameter
/// that turns the sources off, and a bracket that resolves to nothing is left in
/// the sentence and announced rather than deleted.
///
/// The rec's structured `research_note_ids` and its **proved** grade ride on the
/// expanded body rather than the collapsed headline, so one recommendation shows
/// one set of sources and the collapsed row stays the single line legacy draws.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/motion.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:solar_icons/solar_icons.dart';

/// The collapsible "Suggested actions" block.
class ActionsSection extends StatefulWidget {
  /// [recommendations] is the day's set, highest rank first.
  const ActionsSection({required this.recommendations, this.action, super.key});

  /// Today's cited actions.
  final List<Recommendation> recommendations;

  /// `/api/today`'s own top-level `action` — the model's one-line daily
  /// suggestion, **which no legacy file renders**. Legacy reads only
  /// `recommendations[].action` (`today_screen.dart:967`), so this string has
  /// been generated nightly and shown to nobody.
  ///
  /// It goes in the subtitle slot of the block it belongs to, replacing the
  /// generic "N ways to improve today" when the server has warmed one. Null
  /// renders that generic line and nothing else — `docs/APP_DESIGN.md` §3.1:
  /// null means show nothing, never a spinner.
  final String? action;

  @override
  State<ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends State<ActionsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = widget.recommendations;
    // The daily `action` and the recommendation set are written by the same
    // nightly job and either can arrive without the other, so the block draws
    // for either. With neither it draws nothing at all.
    if (items.isEmpty && widget.action == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HTap(
          onTap: items.isEmpty ? null : () => setState(() => _open = !_open),
          semanticLabel: items.isEmpty
              ? null
              : (_open ? 'Hide suggested actions' : 'Show suggested actions'),
          child: InstrumentModule(
            label: '',
            tag: null,
            minHeight: 0,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            children: [
              Row(
                children: [
                  HIconBadge(
                    SolarIconsBold.lightbulb,
                    color: colors.accent,
                    size: 38,
                    radius: 12,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggested actions',
                          style: HType.serif(colors.ink, size: 17),
                        ),
                        const SizedBox(height: 2),
                        if (widget.action case final String daily)
                          GroundedProse(
                            text: daily,
                            style: HType.sans(colors.ink3, size: 12),
                            maxLines: 2,
                          )
                        else
                          Text(
                            '${items.length} '
                            '${items.length == 1 ? 'way' : 'ways'} to improve today',
                            style: HType.sans(colors.ink3, size: 12),
                          ),
                      ],
                    ),
                  ),
                  // No arrow with nothing to expand into: a control that
                  // opens an empty list is a dead control.
                  if (items.isNotEmpty)
                    AnimatedRotation(
                      turns: _open ? 0.25 : 0,
                      duration: HMotion.fast,
                      child: Icon(
                        SolarIconsOutline.altArrowRight,
                        size: 18,
                        color: colors.ink3,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: HMotion.curve,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final rec in items) ...[
                      const SizedBox(height: 8),
                      ActionRow(recommendation: rec),
                    ],
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// One action: its headline, and the reasoning behind it on tap.
class ActionRow extends StatefulWidget {
  /// [recommendation] is one cited action.
  const ActionRow({required this.recommendation, super.key});

  /// What to do, why, and what it should change.
  final Recommendation recommendation;

  @override
  State<ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<ActionRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rec = widget.recommendation;
    final tint = categoryColor(context, rec.category);
    return HTap(
      onTap: () => setState(() => _open = !_open),
      semanticLabel: _open ? 'Hide why' : 'Why this, today',
      child: InstrumentModule(
        label: '',
        tag: null,
        minHeight: 0,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: GroundedProse(
                  text: rec.action,
                  style: HType.sans(
                    colors.ink,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                  maxLines: _open ? null : 1,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: HMotion.fast,
                child: Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 16,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: HMotion.curve,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : _Expanded(recommendation: rec, tint: tint),
          ),
        ],
      ),
    );
  }
}

/// The rationale, the expected effect, and the rec's own sources.
class _Expanded extends StatelessWidget {
  const _Expanded({required this.recommendation, required this.tint});

  final Recommendation recommendation;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rec = recommendation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rec.rationale case final String why) ...[
          const SizedBox(height: 10),
          GroundedProse(
            text: why,
            style: HType.sans(colors.ink2, size: 13, height: 1.5),
            // The structured ids and the PROVED grade hang off the reasoning,
            // which is the field `jobs/recs.py` requires an inline citation in —
            // so one recommendation shows one set of sources.
            alsoCites: rec.researchNoteIds,
            grade: rec.gradeLabel,
          ),
        ],
        if (rec.expectedEffect case final String effect) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(Radii.badge),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(SolarIconsOutline.target, size: 13, color: tint),
                const SizedBox(width: 7),
                Expanded(
                  child: GroundedProse(
                    text: effect,
                    style: HType.sans(colors.ink3, size: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The dot colour for a recommendation's category. Legacy's `catColor` (899).
///
/// The `_` fallback is legacy's own green, so a category the server grows later
/// is drawn in the accent rather than in nothing.
Color categoryColor(BuildContext context, String? category) {
  final colors = context.colors;
  final hues = context.hues;
  return switch (category) {
    'sleep' => hues.sleep,
    'activity' => colors.accent,
    'fitness' => hues.fitness,
    'recovery' => hues.heart,
    'intake' => hues.movement,
    _ => colors.accent,
  };
}
