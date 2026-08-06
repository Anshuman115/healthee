/// The title over a run of cards. **Legacy's `HSectionTitle`, ported.**
///
/// ```text
///   Sleep                                     See all →
/// ```
///
/// Legacy (`ui.dart:174`) draws a display-size title at 23 px on the left and an
/// optional uppercase action link on the right, baseline-aligned, with 12 px of
/// air under the pair and 2 px of inset either side. That is what this is now.
///
/// ## What this replaced, and why it went
///
/// The previous revision was a rebuild invention: a 10 px uppercase label over a
/// hairline `Divider`, tinted by the metric family the section was about. It read
/// well and it is **not what legacy draws**, and legacy is the specification. The
/// per-section tint went with it — legacy's section titles are always ink, and the
/// colour system that made a tinted rule safe (the five identity tags) no longer
/// exists.
///
/// ## The `See all →`
///
/// Legacy's `SectionTitle` takes an action and renders it as `'$action →'` in the
/// green accent at label size. [onSeeAll] and [seeAllLabel] travel together and
/// neither is optional without the other: a label with no destination is a dead
/// control, a destination with no label is an invisible one.
///
/// ## [subtitle] is not legacy's, and is kept deliberately
///
/// Legacy has no subtitle. This one carries honesty wording — what a section's
/// numbers are measured from, when that cannot be said inside a card — which is
/// the one category of addition the port is allowed to make. It renders quietly
/// under the title and is absent unless a caller passes it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/instrument/h_tap.dart';

/// A section title, with an optional action on the right.
class SectionHeading extends StatelessWidget {
  /// [title] names the domain; [subtitle] carries honesty wording when needed.
  const SectionHeading(
    this.title, {
    this.subtitle,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
    super.key,
  });

  /// The domain — "Recovery & heart", "Sleep", "Fitness".
  final String title;

  /// One quiet line under it. Omit unless it earns its place.
  final String? subtitle;

  /// Opens the whole of what this section indexes. Null draws no control.
  final VoidCallback? onSeeAll;

  /// What that control says. Legacy renders it as `LABEL →`.
  final String seeAllLabel;

  /// Legacy's `EdgeInsets.fromLTRB(2, 0, 2, 12)`.
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(2, 0, 2, 12);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HType.serif(colors.ink),
                ),
              ),
              if (onSeeAll case final VoidCallback open)
                HTap(
                  onTap: open,
                  child: Semantics(
                    button: true,
                    label: '$seeAllLabel $title',
                    child: ExcludeSemantics(
                      child: Text(
                        '${seeAllLabel.toUpperCase()} →',
                        style: HType.label(colors.accent),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle case final String line) ...[
            const SizedBox(height: 4),
            Text(line, style: HType.sans(colors.ink3, size: 12)),
          ],
        ],
      ),
    );
  }
}
