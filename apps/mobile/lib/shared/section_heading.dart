/// The quiet rule that separates one domain of a screen from the next.
///
/// Legacy's `today_screen.dart` was organised in domain sections — recovery and
/// heart, sleep, activity, fitness, insights — and that ordering is the product
/// of real use rather than of a metric taxonomy. The headings are what make it
/// legible while scrolling.
///
/// Deliberately small and un-emphatic: [HealtheeColors.ink3] at label size, over
/// a hairline. A heading that competes with the numbers under it is a heading
/// that has misunderstood which is the content.
///
/// ## What [metric] does
///
/// **[metric] tints the rule and the title** when a section is about one metric
/// family. It is a metric **id**, resolved through `MetricHues.tagFor` here — the
/// same one table every grid cell asks — so a heading cannot be given a colour
/// that disagrees with the cards under it, and it cannot be given a judgement
/// colour at all. It is the reason a Sleep screen reads blue and an Activity
/// screen reads violet without either of them saying anything about how the owner
/// did. A section about several families — "Fitness", "In your own data" — names
/// no metric and stays [ink3].
///
/// ## The `See all →` legacy has, and this does not
///
/// `ui.jsx`'s `SectionTitle` takes an action, and `screen_today.jsx` uses it in
/// exactly one place: a `See all →` over "Suggested today" that opens the actions
/// tab. **Actions has no screen**, so the parameter is not here — an unused
/// widget parameter is a shape somebody will fill in eventually, and the only
/// thing it could be filled in with today is a link to a crash. It comes back in
/// the commit that ships that tab, which is three lines and a caller.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A section title, optionally tinted by the metric family it is about.
class SectionHeading extends StatelessWidget {
  /// [title] names the domain; [subtitle] says what it is for, when that helps.
  const SectionHeading(
    this.title, {
    this.subtitle,
    this.metric,
    super.key,
  });

  /// The domain — "Recovery & heart", "Sleep", "Fitness".
  final String title;

  /// One line under it. Omit unless it earns its place.
  final String? subtitle;

  /// A canonical metric id whose family tints this heading, or null when the
  /// section is about several. See the library docstring.
  final String? metric;


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tag = switch (metric) {
      final String id => context.hues.tagFor(id),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: tag?.withValues(alpha: 0.45) ?? colors.line2,
          height: Insets.xl,
          thickness: hairline,
        ),
        Text(
          title.toUpperCase(),
          style: text.labelSmall?.copyWith(
            letterSpacing: 0.9,
            color: tag ?? colors.ink3,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle case final String line) ...[
          const SizedBox(height: Insets.xs),
          Text(line, style: text.bodySmall?.copyWith(color: colors.ink3)),
        ],
      ],
    );
  }
}
