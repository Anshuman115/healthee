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
/// ## Two things it gained
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
/// **[action] is legacy's `SectionTitle` action**: a `See all →` on the right that
/// opens the tab owning the section. `screen_today.jsx` puts one over "Suggested
/// today", and it is what makes Today an index rather than a destination.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A section title, optionally tinted, optionally with a link on the right.
class SectionHeading extends StatelessWidget {
  /// [title] names the domain; [subtitle] says what it is for, when that helps.
  const SectionHeading(
    this.title, {
    this.subtitle,
    this.metric,
    this.action,
    this.onAction,
    super.key,
  });

  /// The domain — "Recovery & heart", "Sleep", "Fitness".
  final String title;

  /// One line under it. Omit unless it earns its place.
  final String? subtitle;

  /// A canonical metric id whose family tints this heading, or null when the
  /// section is about several. See the library docstring.
  final String? metric;

  /// `See all` — the words on the right-hand link.
  final String? action;

  /// What that link does. The link is drawn only when both are given.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tag = switch (metric) {
      final String id => context.hues.tagFor(id),
      _ => null,
    };
    final link = action;
    final onTap = onAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: tag?.withValues(alpha: 0.45) ?? colors.line2,
          height: Insets.xl,
          thickness: hairline,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  letterSpacing: 0.9,
                  color: tag ?? colors.ink3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (link != null && onTap != null)
              // The accent, not the tag: this is a control, and the accent is
              // what `tokens.dart` reserves for the things the owner can press.
              // Tinting it with the section's tag would hide the one difference
              // that matters here.
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(Radii.chip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.xs,
                    vertical: 2,
                  ),
                  child: Text(
                    '$link →',
                    style: text.labelMedium?.copyWith(color: colors.accent),
                  ),
                ),
              ),
          ],
        ),
        if (subtitle case final String line) ...[
          const SizedBox(height: Insets.xs),
          Text(line, style: text.bodySmall?.copyWith(color: colors.ink3)),
        ],
      ],
    );
  }
}
