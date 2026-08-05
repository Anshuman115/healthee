/// The Sleep screen's loading shape.
///
/// **Ported verbatim** from `healthee-legacy/app/lib/ui/skeletons.dart`'s
/// `SleepSkeleton` — heading · hero figure · the collapsed AI card · the gauge
/// and its stats · two rich cards at legacy's 36 px and 120 px chart heights.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/skeletons/h_skeleton.dart';

/// Sleep, while it loads.
class SleepSkeleton extends StatelessWidget {
  /// Draws the placeholder.
  const SleepSkeleton({super.key});

  /// Legacy's `EdgeInsets.fromLTRB(18, 16, 18, 120)`.
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(18, 16, 18, 120);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ListView(
      padding: _padding,
      children: const [
        HSkeleton(width: 200, height: 11),
        SizedBox(height: 12),
        HSkeleton(width: 120, height: 34, radius: 8),
        SizedBox(height: 18),
        // The collapsed AI card.
        SkeletonCard(
          child: Row(
            children: [
              HSkeleton(width: 36, height: 36, radius: 11),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HSkeleton(width: 130, height: 14),
                  SizedBox(height: 7),
                  HSkeleton(width: 80, height: 10),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        // The hero: gauge plus its stat column.
        SkeletonCard(
          child: Row(
            children: [
              HSkeleton(width: 100, height: 100, radius: 50),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HSkeleton(width: 70, height: 9),
                    SizedBox(height: 10),
                    HSkeleton(width: 110, height: 26, radius: 7),
                    SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: HSkeleton(height: 13)),
                        SizedBox(width: 20),
                        Expanded(child: HSkeleton(height: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        SkeletonRichCard(chartHeight: 36),
        SizedBox(height: 10),
        SkeletonRichCard(chartHeight: 120),
      ],
    ),
  );
}
