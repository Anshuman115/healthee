/// The quiet rule that separates one domain of Today from the next.
///
/// Legacy's `today_screen.dart` was organised in domain sections — recovery and
/// heart, sleep, activity, fitness, insights — and that ordering is the product
/// of real use rather than of a metric taxonomy. The headings are what make it
/// legible while scrolling.
///
/// Deliberately small and un-emphatic: [HealtheeColors.ink3] at label size, over
/// a hairline. A heading that competes with the numbers under it is a heading
/// that has misunderstood which is the content.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A section title, optionally with one line of context under it.
class SectionHeading extends StatelessWidget {
  /// [title] names the domain; [subtitle] says what it is for, when that helps.
  const SectionHeading(this.title, {this.subtitle, super.key});

  /// The domain — "Recovery & heart", "Sleep", "Fitness".
  final String title;

  /// One line under it. Omit unless it earns its place.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.line2, height: Insets.xl, thickness: hairline),
        Text(
          title.toUpperCase(),
          style: text.labelSmall?.copyWith(letterSpacing: 0.9),
        ),
        if (subtitle case final String line) ...[
          const SizedBox(height: Insets.xs),
          Text(line, style: text.bodySmall?.copyWith(color: colors.ink3)),
        ],
      ],
    );
  }
}
