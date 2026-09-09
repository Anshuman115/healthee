/// The options behind an [HSelect], as a sheet rather than a floating menu.
///
/// ## Why this exists
///
/// `DropdownButtonFormField` opens Material's own overlay: a surface that
/// measures itself against the field, lands wherever there is room, paints its
/// own elevation and shadow, and highlights on tap with the splash this app
/// switched off everywhere else. On the profile screen it covered the label of
/// the field it belonged to and truncated the longest option — which is the one
/// case where the owner most needs to read it, since `Usual activity` is a
/// self-report whose whole meaning is in the wording.
///
/// A sheet is the control this app already uses whenever a choice needs room:
/// the day picker, the journal log, the evidence list. Routing the select
/// through [showAppSheet] makes it the same object — same ground, same corner,
/// same grab handle, same root navigator — instead of the one place Material
/// still shows through.
///
/// ## The selected option is marked, not merely coloured
///
/// A tick as well as the accent. Colour alone is the weaker signal, and this
/// screen is read by somebody checking what they answered.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/sheets/app_sheet.dart';
import 'package:solar_icons/solar_icons.dart';

/// Opens [items] as a sheet under [title] and resolves to the one chosen.
///
/// Resolves to null when the sheet is dismissed without a choice — **which is
/// not the same as choosing null**, and callers must not treat it as clearing
/// the field. Every call site here passes the result straight back to the
/// control's own `onChanged` only when it is non-null.
Future<T?> chooseInSheet<T>({
  required BuildContext context,
  required String title,
  required List<(T, String)> items,
  required T? value,
}) => showAppSheet<T>(
  context: context,
  builder: (context) =>
      _ChoiceSheet<T>(title: title, items: items, value: value),
);

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.items,
    required this.value,
  });

  static const double rowPad = 15;
  static const double tickSize = 19;

  final String title;
  final List<(T, String)> items;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
        border: Border.all(color: colors.line),
      ),
      padding: EdgeInsets.fromLTRB(22, 12, 22, 24 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: HType.serif(colors.ink, size: 24)),
            const SizedBox(height: 12),
            for (final (int index, (T option, String label)) in items.indexed)
              _Option<T>(
                option: option,
                label: label,
                chosen: option == value,
                first: index == 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _Option<T> extends StatelessWidget {
  const _Option({
    required this.option,
    required this.label,
    required this.chosen,
    required this.first,
  });

  final T option;
  final String label;
  final bool chosen;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!first) SizedBox(height: hairline, child: ColoredBox(color: colors.line)),
        Semantics(
          selected: chosen,
          button: true,
          child: HTap(
            onTap: () => Navigator.of(context).pop(option),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: _ChoiceSheet.rowPad,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      // The sheet has the width the menu did not: the longest
                      // option is the one whose wording carries the meaning.
                      style: FormType.fieldInput.copyWith(
                        color: chosen ? colors.accent : colors.ink,
                        fontWeight: chosen ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: _ChoiceSheet.tickSize,
                    child: chosen
                        ? Icon(
                            SolarIconsOutline.checkCircle,
                            size: _ChoiceSheet.tickSize,
                            color: colors.accent,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
