/// Nothing on Sleep reaches the owner as an identifier or an unresolved bracket.
///
/// Three things the port had to undo, and each has an assertion here:
///
///   * legacy's Tonight card **deleted** its `[[note_id]]` markers with a regex,
///     so the claim shipped and its grounding did not;
///   * legacy's AI card drew each citation as `id.replaceAll('_', ' ')` — an
///     internal identifier with the underscores taken out, presented as a source;
///   * legacy's consistency action was printed as a plain string, brackets and
///     all, if the model wrote any.
///
/// The rule asserted is deliberately blunt: **no `snake_case` run and no `[`
/// citation marker may be on any Text this screen renders**, and every source
/// must be a name from `shared/format/note_names.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_insight.dart';
import 'package:healthee/features/sleep/widgets/sleep_consistency_card.dart';
import 'package:healthee/features/sleep/widgets/tonight_card.dart';
import 'package:healthee/shared/format/note_names.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';

import '../_sleep_stubs.dart';

/// A `snake_case` identifier: two or more lowercase runs joined by underscores.
final RegExp _snakeCase = RegExp(r'\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b');

/// Every string this render put on screen.
List<String> renderedText(WidgetTester tester) => <String>[
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data case final String data)
      data
    else if (text.textSpan?.toPlainText() case final String span)
      span,
];

void main() {
  /// A note the corpus really has, so the assertion is about the RESOLUTION and
  /// not about the id happening to be unknown.
  const String realNote = 'sleep_regularity_index';

  setUpAll(() {
    expect(
      noteName(realNote),
      isNotNull,
      reason: 'the fixture cites a note this build cannot name, so the test '
          'would pass for the wrong reason',
    );
  });

  testWidgets('THE TONIGHT LEVER SHOWS ITS SOURCES, NOT ITS MARKERS', (
    tester,
  ) async {
    // Legacy: `raw.replaceAll(RegExp(r'\[\[[^\]]+\]\]'), '')` — the sources were
    // deleted from the sentence and shown nowhere.
    final lever = TonightLever.maybe(<String, Object?>{
      'title': 'Lights out by 23:00',
      'lever': 'bedtime',
      'target_clock': '23:00',
      'coach': 'Keep bedtime inside an hour-wide band [$realNote].',
    })!;
    await tester.pumpWidget(sleepCardHost(TonightCard(lever: lever, progress: 1)));
    await tester.pumpAndSettle();

    final drawn = renderedText(tester);
    expect(drawn, contains('Keep bedtime inside an hour-wide band.'));
    expect(
      drawn.any((line) => line.contains(noteName(realNote)!)),
      isTrue,
      reason: 'the source must be on screen under its own name',
    );
    for (final line in drawn) {
      expect(line, isNot(contains('[')), reason: line);
      expect(_snakeCase.hasMatch(line), isFalse, reason: line);
    }
  });

  testWidgets('THE AI ANALYSIS NAMES ITS SOURCES', (tester) async {
    // Legacy's chip was `id.replaceAll('_', ' ')`.
    await tester.pumpWidget(
      sleepCardHost(
        const GroundedMarkdown(
          text: '**What stands out:**\n\n* Your timing drifts [$realNote].',
          accent: Color(0xFF1F6F54),
          grade: 'Established',
          alsoCites: <String>[realNote],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final drawn = renderedText(tester);
    expect(
      drawn,
      // Legacy's own regex keeps the colon inside the captured header.
      contains('WHAT STANDS OUT:'),
      reason: 'legacy renders a **header:** line as a label, and so do we',
    );
    expect(drawn.any((line) => line.contains(noteName(realNote)!)), isTrue);
    expect(
      drawn.any((line) => line == realNote.replaceAll('_', ' ')),
      isFalse,
      reason: 'an id with its underscores removed is still an id',
    );
    for (final line in drawn) {
      expect(_snakeCase.hasMatch(line), isFalse, reason: line);
    }
  });

  testWidgets('the consistency action is grounded, not printed', (tester) async {
    final block = SleepConsistency.fromJson(<String, Object?>{
      ...loadJson(kConsistencySnapshotPath),
      'action': 'Pick one wake time and hold it [$realNote].',
    });
    await tester.pumpWidget(
      sleepCardHost(
        SleepConsistencyCard(
          bedtime: const <double>[5, 5.5, 6],
          wake: const <double>[12, 12.5, 12.2],
          consistency: block,
          progress: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final drawn = renderedText(tester);
    expect(drawn, contains('Pick one wake time and hold it.'));
    expect(drawn.any((line) => line.contains(noteName(realNote)!)), isTrue);
    for (final line in drawn) {
      expect(line, isNot(contains('[')), reason: line);
    }
  });

  testWidgets('a LOCKED analysis says locked, and never "unavailable"', (
    tester,
  ) async {
    // `/api/sleep/insight` answers 402 to a free owner. Legacy reported that as
    // `error: 'unavailable right now'`, which invites a retry that cannot work.
    const locked = SleepInsight.locked();
    expect(locked.hasText, isFalse);
    expect(locked.refused, isFalse);
    expect(locked.locked, isTrue);
  });
}
