/// `H.evidenceSheet` — "Behind the explanation", as a root-presented sheet.
///
/// The prototype's evidence control is a `.text-button` that opens a dialog with
/// a badge, a heading, the excerpt and a closing sentence about context. This is
/// that, with the one difference the honesty layer forces: the excerpt is the
/// server's own prose, so it goes through [GroundedProse] rather than a `Text` —
/// which is what keeps a `[note_id]` marker from reaching a screen and what puts
/// the sources under the claim they belong to.
///
/// It is opened through [showAppSheet], which is the app's one presentation: a
/// sheet raised on a branch navigator leaves the tab bar live under its own
/// scrim. `test/features/sheet_layering_test.dart` scans `lib/` and fails the
/// build on any other way of raising one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/v02/surfaces.dart';

/// The prototype's own closing paragraph, verbatim.
const String kEvidenceContext =
    'Your wearable provides estimates. Personal patterns are not a diagnosis, '
    'and observations do not establish a cause.';

/// Its heading.
const String kEvidenceContextTitle = 'Keep it in context';

/// Opens the evidence behind one piece of generated prose.
void showEvidenceSheet(
  BuildContext context, {
  required String title,
  required String prose,
  List<String> alsoCites = const <String>[],
  String? grade,
}) {
  unawaited(
    showAppSheet<void>(
      context: context,
      builder: (context) => _EvidenceSheet(
        title: title,
        prose: prose,
        alsoCites: alsoCites,
        grade: grade,
      ),
    ),
  );
}

class _EvidenceSheet extends StatelessWidget {
  const _EvidenceSheet({
    required this.title,
    required this.prose,
    required this.alsoCites,
    required this.grade,
  });

  final String title;
  final String prose;
  final List<String> alsoCites;
  final String? grade;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: sheetBottomInset(context)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.line, width: hairline)),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (grade case final String proven)
                  StatusBadge(proven, accented: true),
                const SizedBox(height: Insets.md),
                Text(
                  title,
                  style: TypeScale.detailTitle.copyWith(color: colors.ink),
                ),
                const SizedBox(height: Insets.md),
                GroundedProse(
                  text: prose,
                  style: TypeScale.small.copyWith(color: colors.ink2),
                  alsoCites: alsoCites,
                ),
                const CardDivider(),
                Text(
                  kEvidenceContextTitle,
                  style: TypeScale.rowTitle.copyWith(color: colors.ink),
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  kEvidenceContext,
                  style: TypeScale.small.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
