/// The Today screen's loading shape.
///
/// **Ported verbatim** from `healthee-legacy/app/lib/ui/skeletons.dart`'s
/// `TodaySkeleton` — the same padding, the same gaps, the same order: greeting ·
/// two summary lines · the recovery card · three two-up grid rows · a section
/// label · a rich card.
///
/// It is content-shaped rather than a spinner on purpose: the screen that arrives
/// occupies exactly this space, so nothing jumps when it does.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/skeletons/h_skeleton.dart';

/// Today, while it loads.
class TodaySkeleton extends StatelessWidget {
  /// Draws the placeholder.
  const TodaySkeleton({super.key});

  /// Legacy's `EdgeInsets.fromLTRB(20, 12, 20, 120)`.
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 12, 20, 120);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ListView(
      padding: _padding,
      children: const [
        // Greeting — avatar and two lines of name.
        Row(
          children: [
            HSkeleton(width: 46, height: 46, radius: 23),
            SizedBox(width: 13),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HSkeleton(width: 150, height: 17),
                SizedBox(height: 8),
                HSkeleton(width: 86, height: 11),
              ],
            ),
          ],
        ),
        SizedBox(height: 24),
        // The two-line recovery summary.
        HSkeleton(width: double.infinity, height: 15),
        SizedBox(height: 9),
        HSkeleton(width: 210, height: 15),
        SizedBox(height: 18),
        // The recovery card.
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HSkeleton(width: 120, height: 10),
              SizedBox(height: 16),
              HSkeleton(width: double.infinity, height: 38, radius: 10),
              SizedBox(height: 12),
              HSkeleton(width: double.infinity, height: 13),
              SizedBox(height: 8),
              HSkeleton(width: 190, height: 13),
            ],
          ),
        ),
        SizedBox(height: 12),
        // The metric grid.
        SkeletonTileRow(),
        SizedBox(height: 10),
        SkeletonTileRow(),
        SizedBox(height: 10),
        SkeletonTileRow(),
        SizedBox(height: 24),
        // A section, and the first card under it.
        HSkeleton(width: 74, height: 11),
        SizedBox(height: 12),
        SkeletonRichCard(),
      ],
    ),
  );
}
