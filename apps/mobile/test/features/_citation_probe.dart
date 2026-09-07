/// How `citation_sweep_test.dart` looks at a surface — the instruments, not the
/// claims.
///
/// Split out at 459 lines (Standards section 1: one responsibility per file).
/// The suite says what must be true of every card; this file says how you find
/// out, and the two change for different reasons — a new surface edits the
/// suite, a new way of measuring edits this.
///
/// Two instruments, and both exist because the obvious version is wrong:
///
///   * [sourceLines] reads `lib/` itself. A rendered suite can only see screens
///     somebody wrote a suite for, so it cannot prove a rule about *every* card;
///     a source scan has no such blind spot. Same shape as
///     `test/core/colour_literal_gate_test.dart`.
///   * [wordsOn] measures **painted rects**, not the widget tree. A chip is on a
///     card's face when its ink lands on the card, and `findsNothing` on a type
///     cannot tell that from a chip drawn one pixel outside — or from a widget
///     that is present and paints nothing at all, which is exactly what
///     `MetricInfoDot` does when it has no sources to carry.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/shared/format/note_names.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';

/// The handset widths every geometric claim is made at.
///
/// 320 is the narrowest phone this app is built for and it is the one that
/// matters: it is where a chip that "fits" starts painting past the card.
/// Flutter's own 800 px default is not a phone.
const List<double> kSweptWidths = <double>[320, 360, 390, 414];

/// The ONLY files that may render a citation where the reader already is, and
/// the reason each one may.
///
/// Anything else — every card, panel, tile and field under `lib/features/`, and
/// every card surface in `lib/shared/` — sends its sources to the ⓘ.
const Map<String, String> kInlineGrounding = <String, String>{
  'lib/shared/states/citation_row.dart': 'the widget itself',
  'lib/shared/states/grounded_text.dart':
      'server prose: the citation is the sentence’s own grounding',
  'lib/shared/states/grounded_markdown.dart':
      'the same, for prose that arrives with markup',
  'lib/shared/metric_info/metric_info_sheet.dart':
      'the ⓘ — the destination everything above is swept into',
};

/// A citation chip being BUILT. Not the word: the type is named in a dozen
/// docstrings that are arguing for exactly this rule.
final RegExp kChip = RegExp(r'\bCitationRow\s*\(');

/// A `Reference …` label as a string literal — the other half of what the owner
/// asked us to take off the cards.
final RegExp kReferenceLabel = RegExp('[\'"]Reference[ :]');

/// One line of first-party source, with where it came from.
typedef SourceLine = ({String path, String where, String text});

/// Every non-comment line of hand-written Dart under `lib/`.
///
/// Generated code is skipped for the reason `analysis_options.yaml` skips it,
/// and comment lines are skipped because the rule the suite enforces is argued
/// for by name in a dozen docstrings.
List<SourceLine> sourceLines() {
  final lines = <SourceLine>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.endsWith('.g.dart') ||
        entity.path.endsWith('.drift.dart')) {
      continue;
    }
    final path = entity.path.replaceAll(r'\', '/');
    final read = entity.readAsLinesSync();
    for (var i = 0; i < read.length; i++) {
      if (read[i].trimLeft().startsWith('//')) {
        continue;
      }
      lines.add((path: path, where: '$path:${i + 1}', text: read[i]));
    }
  }
  return lines;
}

/// The screen at [width], with the surface under test on it.
Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view
    ..physicalSize = Size(width, 1200)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

/// The words actually PAINTED inside [where]. See the library docstring.
List<String> wordsOn(WidgetTester tester, Rect where) {
  final said = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) {
      continue;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!where.overlaps(rect)) {
      continue;
    }
    final text = element.widget as Text;
    final words = text.data ?? text.textSpan?.toPlainText();
    if (words != null) {
      said.add(words);
    }
  }
  return said;
}

/// The one ⓘ inside [surface].
Finder dotIn(Finder surface) =>
    find.descendant(of: surface, matching: find.byType(MetricInfoDot));

/// The dot is drawn at its own size, on the surface, and not past its edge.
void expectDotSits(WidgetTester tester, Finder dot, Rect surface) {
  final rect = tester.getRect(dot);
  expect(rect.height, closeTo(16, 0.5), reason: 'legacy’s 16 px glyph');
  expect(rect.width, greaterThanOrEqualTo(16));
  expect(
    surface.contains(rect.center),
    isTrue,
    reason: 'the ⓘ is painted at $rect, outside its own surface $surface',
  );
  expect(rect.right, lessThanOrEqualTo(surface.right + 0.5));
}

/// Opens [dot] and reads [ids] back out of the sheet, as painted source names.
///
/// The names, not the ids: an id is what the payload carried, and a sheet that
/// resolved none of them would still "contain" every id as a tooltip.
Future<void> readIdsFromDot(
  WidgetTester tester,
  Finder dot,
  List<String> ids,
  double width,
) async {
  await tester.tap(dot);
  await tester.pumpAndSettle();
  for (final id in ids) {
    final name = noteName(id);
    expect(name, isNotNull, reason: '$id resolves to no source name');
    final chip = find.text(name!);
    expect(
      chip,
      findsOneWidget,
      reason: '$id was taken off the card and is not in its ⓘ',
    );
    final rect = tester.getRect(chip);
    expect(rect.isEmpty, isFalse, reason: '“$name” occupies no space');
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(
      rect.right,
      lessThanOrEqualTo(width),
      reason: '“$name” is painted past the ${width.toInt()} px edge',
    );
  }
}
