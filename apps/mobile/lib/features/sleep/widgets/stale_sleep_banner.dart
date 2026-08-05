/// "No sleep recorded last night" — the banner that dates the whole page.
///
/// **Legacy** `sleep_screen.dart:44` (`_StaleSleepBanner`). A `cSteps`-tinted
/// squircle at 12% fill with a 35% border, a bedtime icon, the headline at
/// `sans(ink, 13, w700)` and the dating line at `sans(ink3, 11)`.
///
/// It is the honesty guard legacy already had and it is worth keeping loud: with
/// it, everything below is correctly read as being about an older night; without
/// it, a two-day-old session is indistinguishable from last night's.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';

/// Legacy's stale-sleep banner.
class StaleSleepBanner extends StatelessWidget {
  /// [label] is the night's own caption — `2 nights ago`.
  const StaleSleepBanner(this.label, {super.key});

  /// How stale the session is, in the page's own words.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: hues.steps.withValues(alpha: 0.12),
        shape: hSquircle(
          Radii.badge,
          side: BorderSide(color: hues.steps.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.bedtime_outlined, size: 18, color: hues.steps),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'No sleep recorded last night',
                  style: HType.sans(colors.ink, size: 13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Everything below is from your last sleep · $label',
                  style: HType.sans(colors.ink3, size: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
