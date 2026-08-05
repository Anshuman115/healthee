/// The page's own header — the dated eyebrow and the word "Sleep".
///
/// **Legacy** `sleep_screen.dart:253–257`. An eyebrow at 10 px / 0.12 em reading
/// `LAST NIGHT · 11:30P – 6:30A`, 8 px, the title at `serif(ink, 38)`, then 18 px
/// before the first card.
///
/// **The clock range is dropped rather than dashed** when there is no session
/// behind the night. Legacy printed `— – —`, which is two dashes where two times
/// belong; an eyebrow that simply says `LAST NIGHT` claims nothing it cannot back.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/instrument_module.dart';

/// Legacy's Sleep page header.
class SleepPageHead extends StatelessWidget {
  /// [label] is the night's caption; [start] and [end] are its clock range.
  const SleepPageHead({
    required this.label,
    required this.start,
    required this.end,
    super.key,
  });

  /// `Last night` · `Night before last` · `3 nights ago`.
  final String label;

  /// When the session began, or null when there is none.
  final DateTime? start;

  /// When it ended.
  final DateTime? end;

  /// The eyebrow's text, range included only when both ends exist.
  String get eyebrow => start == null || end == null
      ? label
      : '$label · ${clock(start!)} – ${clock(end!)}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ModuleLabel(eyebrow, size: 10),
        const SizedBox(height: 8),
        Text('Sleep', style: HType.serif(colors.ink, size: 38)),
        const SizedBox(height: 18),
      ],
    );
  }
}
