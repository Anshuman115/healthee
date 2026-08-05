/// A number on a Sleep card, or the hole where it would have been — and the one
/// line at the card's foot that says why.
///
/// ## What this replaces
///
/// Legacy printed `'—'` for every absent value on this screen: the hero score,
/// time asleep, efficiency, all six overnight vitals, the SRI, every trend. A
/// dash occupies a number's slot and says nothing, so "the strap was off your
/// wrist", "the server has not derived it yet" and "we have a bug" all render
/// identically. The product's premise is that they must not.
///
/// So a value slot is [SleepFigure] — the number, or a [ValueHole] the size the
/// number would have been — and the card carries a [SleepGapNote] naming what is
/// missing and why. Two properties make that honest rather than decorative:
///
///   * **The hole keeps the number's footprint**, so nothing on the card moves
///     and the port stays verbatim. A slot that collapsed would be a layout
///     change wearing an honesty argument.
///   * **The note is built from the same readings the card drew.** It iterates
///     what it was given rather than naming the fields somebody remembered, which
///     is the difference between a check and a comment — `test/mutations.sh`
///     blanks a value on purpose and requires the note to notice.
///
/// A full [WithheldCard] is deliberately NOT used here. It is a card, and these
/// are cells inside one; six of them stacked would replace the night's detail
/// with six paragraphs of the same sentence.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// One value slot: the formatted number, or a hole its size.
///
/// [reading] is a `Reading<String>` — **already formatted** — because
/// `Reading.map` is the honesty layer's own way to convert a value while
/// carrying its state through unchanged. A widget that took a raw number and a
/// formatter would have to unwrap and re-wrap, which is the step where a caveat
/// gets dropped (`reading.dart` says so at the definition of `map`).
class SleepFigure extends StatelessWidget {
  /// [style] is the style the number would have worn.
  const SleepFigure({
    required this.reading,
    required this.style,
    required this.holeWidth,
    super.key,
  });

  /// The formatted value and its honesty state.
  final Reading<String> reading;

  /// The text style the number would have worn.
  final TextStyle style;

  /// How wide the hole is. Chosen per slot so the card does not reflow.
  final double holeWidth;

  @override
  Widget build(BuildContext context) {
    final value = reading.valueOrNull;
    if (value == null) {
      return ValueHole(
        width: holeWidth,
        // The glyph height the figure would have occupied, so the row keeps its
        // baseline rather than shrinking around the absence.
        height: (style.fontSize ?? 14) * 0.9,
        radius: Radii.inlineHole,
      );
    }
    return Text(value, style: style);
  }
}

/// The line under a card naming every value it could not show, and why.
///
/// [fields] maps the owner-facing name of each slot to the reading behind it.
/// Only the withheld ones are printed, grouped by reason so one cause is one
/// sentence — six vitals missing for the same reason is one line, not six.
class SleepGapNote extends StatelessWidget {
  /// Renders the gaps in [fields]. Draws nothing when there are none.
  const SleepGapNote({required this.fields, super.key});

  /// Slot name → the reading that filled it.
  final Map<String, Reading<Object>> fields;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final grouped = groupGaps(fields);
    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in grouped.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Text(
                '${_list(entry.value.names)} not shown. ${entry.value.message}',
                style: HType.sans(colors.ink3, size: 11.5, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  /// `A`, `A and B`, `A, B and C`.
  static String _list(List<String> names) {
    if (names.length == 1) {
      return names.single;
    }
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}

/// One reason, and every slot that went missing for it.
@immutable
class SleepGapGroup {
  /// Builds a group.
  const SleepGapGroup({required this.names, required this.message});

  /// The owner-facing names of the slots, in the order the card drew them.
  final List<String> names;

  /// The second-person sentence from the disclosure they share.
  final String message;
}

/// Groups the withheld entries of [fields] by the reason they share.
///
/// Public because the honesty tests assert over this rather than over pixels: a
/// card that blanks a value and does not report it fails here, and a test that
/// only looked for a hole on screen could not tell the two apart.
Map<String, SleepGapGroup> groupGaps(Map<String, Reading<Object>> fields) {
  final grouped = <String, SleepGapGroup>{};
  fields.forEach((name, reading) {
    final disclosure = _reasonOf(reading);
    if (disclosure == null) {
      return;
    }
    final existing = grouped[disclosure.reason];
    grouped[disclosure.reason] = SleepGapGroup(
      names: <String>[...?existing?.names, name],
      message: disclosure.message,
    );
  });
  return grouped;
}

/// The disclosure behind an absence, or null when the reading has a value.
///
/// The exhaustive switch is the point: a fifth [Reading] case stops this
/// compiling until somebody decides whether it is an absence worth naming.
Disclosure? _reasonOf(Reading<Object> reading) => switch (reading) {
  Present<Object>() => null,
  Caveated<Object>() => null,
  Withheld<Object>(:final disclosure) => disclosure,
  Excluded<Object>(:final exclusions) => exclusions.isEmpty ? null : exclusions.first,
};
