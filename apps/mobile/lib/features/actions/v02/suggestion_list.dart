/// Actions in the shape of the reference design — a status ring, then an
/// accordion of suggestions with one open at a time.
///
/// `design_reference/project/screens/v2-actions.png`, which the legacy Flutter
/// app never built: its own Actions screen was three plain lists (Active,
/// Suggested, Completed). This is the mockup's form.
///
/// ## What the mockup does that a deck did not
///
/// A deck marches the owner through one decision at a time and hides the rest.
/// The reference shows **all of them at once** as compact rows — icon, title,
/// category — and opens one inline. You can see what is on offer before
/// choosing what to read, which is the difference between being asked and
/// choosing.
///
/// ## ⛔ Two things in the mockup this app may not say
///
/// **"You've practiced 2 of 3 habits today."** Nothing here observes practice.
/// `actions_v02_test.dart` pins it: *"adoption records an intention; nothing
/// observes the doing"*, and there is no completion signal on the wire. The
/// ring counts what the owner **said yes to**, and the words say so.
///
/// **"A small win is still a win."** Encouragement about a number the app has
/// not measured. Dropped rather than reworded — the honest version of that
/// sentence is the count itself.
///
/// The mockup's `CIRCADIAN · 10 MIN` loses its `10 MIN` for the same reason:
/// no recommendation on this wire carries a time cost, and the layout must not
/// invent one.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/features/actions/v02/deck_item.dart';
import 'package:healthee/features/actions/v02/suggestion_row.dart';
import 'package:healthee/features/actions/v02/working_on.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/surface_cards.dart';

/// The screen's suggestions: the ring, the heading, the accordion.
class SuggestionList extends ConsumerStatefulWidget {
  /// [recommendations] is today's set, already dated upstream.
  const SuggestionList({required this.recommendations, super.key});

  /// Today's recommendations, in the server's order.
  final List<Recommendation> recommendations;

  /// The mockup's section heading.
  static const String heading = 'Suggested for you';

  @override
  ConsumerState<SuggestionList> createState() => _SuggestionListState();
}

class _SuggestionListState extends ConsumerState<SuggestionList> {
  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(commitmentRepositoryProvider).value;
    final challenges = ref.watch(challengeFeedProvider).value?.data;
    final programs = ref.watch(programFeedProvider).value?.data;
    final items = <DeckItem>[
      for (final rec in widget.recommendations)
        DeckItem.recommendation(rec, ref),
      if (repository != null)
        for (final challenge in challenges?.suggested ?? const <Challenge>[])
          DeckItem.challenge(challenge, repository, ref),
      // ⛔ The third feed, which had no route to any screen. `actions_screen`
      // mounts only the RUNNING section on the principle that "what was merely
      // on offer is in the deck above" — and the deck knew about two feeds of
      // the three, so a program the coach designed was stored, served, and drawn
      // nowhere. LAST, because a ladder is the longest horizon on the screen and
      // the deck reads shortest-first.
      if (repository != null)
        for (final program in programs?.suggested ?? const <HealthProgram>[])
          DeckItem.program(program, repository, ref),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Standing(items: items),
        const SizedBox(height: 16),
        Text(
          SuggestionList.heading,
          style: HType.serif(context.colors.ink, size: 17),
        ),
        const SizedBox(height: 9),
        if (items.isEmpty)
          const PanelNote(
            'Nothing suggested today. Actions are written overnight from the '
            'readings the server has, and only where a reading actually raised '
            'one.',
          )
        else
          for (final (int i, DeckItem item) in items.indexed) ...<Widget>[
            if (i > 0) const SizedBox(height: 7),
            SuggestionRow(item: item),
          ],
        if (repository != null) ...<Widget>[
          const SizedBox(height: 14),
          Refill(ref: ref, repository: repository),
        ],
      ],
    );
  }
}

/// The mockup's status card — a ring, and what it counts.
class _Standing extends StatelessWidget {
  const _Standing({required this.items});

  static const double ring = 34;
  static const double stroke = 3;

  final List<DeckItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = items.length;
    final taken = items.where((item) => item.adopted).length;
    return PlainCard(
      inset: 12,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: ring,
            height: ring,
            child: CustomPaint(
              painter: _RingPainter(
                fraction: total == 0 ? 0 : taken / total,
                track: colors.line2,
                fill: colors.accent,
              ),
              child: Center(
                child: Text(
                  '$taken/$total',
                  style: TypeScale.tinyLabel.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  total == 0 ? 'Nothing to decide' : 'What you’ve taken on',
                  style: HType.serif(colors.ink, size: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  // Intentions, never practice — see the library docstring.
                  total == 0
                      ? 'No suggestions are open today.'
                      : 'Yes to $taken of $total today. Nothing checks whether '
                            'you did them.',
                  style: TypeScale.panelNote.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - _Standing.stroke) / 2;
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = _Standing.stroke;
    canvas.drawCircle(centre, radius, base);
    if (fraction <= 0) {
      return;
    }
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _Standing.stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.fill != fill;
}

