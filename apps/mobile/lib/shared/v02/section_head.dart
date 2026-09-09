/// `.section-head` — the heading above a group of panels.
///
/// ```css
/// .section-head    { display: flex; justify-content: space-between;
///                    align-items: center; margin-bottom: 12px; gap: 8px; }
/// .section-head h2 { font-size: 18px; }          /* richer.css */
/// h2               { line-height: 1.4; letter-spacing: -.6px;
///                    font-weight: 700; }         /* styles.css */
/// ```
///
/// `.section { margin-top: 24px }` is the caller's; see `panel.dart` for why a
/// widget does not reserve space above itself.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/page_section.dart';

/// A section heading, with an optional trailing text action.
class SectionHead extends StatelessWidget {
  /// Builds a heading. [onAction] without [actionLabel] draws nothing.
  const SectionHead({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// `.section-head { margin-bottom: 12px }`.
  static const double bottomGap = PageSpacing.afterHeading;

  /// `.section-head { gap: 8px }`.
  static const double gap = 8;

  /// `.section { margin-top: 24px }` — for the caller to apply.
  static const double sectionGap = 24;

  /// The section's name.
  final String title;

  /// The trailing text button's label. Null draws no action.
  final String? actionLabel;

  /// What the action does.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = actionLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: TypeScale.sectionTitle.copyWith(color: colors.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(width: gap),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.family,
                textStyle: TypeScale.textButton,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
