/// `.journal-strip` — the daily check-in, and the one control that opens it.
///
/// ```css
/// .journal-strip    { display:flex; justify-content:space-between;
///                     align-items:center; padding:16px 20px;
///                     background:var(--surface); border:1px solid var(--line);
///                     border-radius:20px }
/// .journal-strip h3 { font-size:13px }
/// .journal-strip p  { font-size:10px }
/// ```
///
/// Replaces `shared/journal_link.dart`'s `ListTile` on the redesigned screens.
/// The copy is the prototype's own: it names three things the strap cannot
/// measure rather than describing a feature, which is the difference between an
/// invitation and a menu item.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/controls.dart';
import 'package:solar_icons/solar_icons.dart';

/// The prototype's own heading.
const String kJournalStripTitle = 'There’s more to your day.';

/// And its line.
const String kJournalStripBody = 'Coffee, a walk, how you felt.';

/// The check-in strip.
class JournalStrip extends StatelessWidget {
  /// [onOpen] pushes the journal.
  const JournalStrip({required this.onOpen, super.key});

  /// `padding: 16px 20px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  /// `border-radius: 20px`.
  static const double radius = 20;

  /// Opens the journal.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: hSquircle(
          radius,
          side: BorderSide(color: colors.line, width: hairline),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  kJournalStripTitle,
                  style: TypeScale.rowTitle.copyWith(color: colors.ink),
                ),
                Text(
                  kJournalStripBody,
                  style: TypeScale.formNote.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledIconButton(
            icon: SolarIconsOutline.addCircle,
            semanticLabel: 'Open journal',
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
