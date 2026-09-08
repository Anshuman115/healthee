/// The grade stamp covers every source the sheet lists under it (audit A4).
///
/// ## The defect
///
/// `_MetricInfoSheet._notes` merges the explainer's static ids with `detail.notes`
/// — the ids the SERVER sent for this particular figure — and hands the merged
/// list to `DetailGrounding` as the sources to name. The grade stamped over them
/// was computed from the static half alone:
///
/// ```dart
/// fallbackGrade: explainer == null ? null : weakestGrade(explainer.notes)
/// ```
///
/// Two live payload paths ship a **Contested** id that no static list carries:
///
///   * `read/vo2max.py:125` — `METHOD_RESERVE: ["vo2max", "hr_reserve_vo2max"]`
///   * `read/activity.py:70` — `"training_load_acwr"`
///
/// So the sheet listed a Contested note as a source and stamped the block
/// **Probable**. The server's own rule is the opposite in both places it exists:
/// `jobs/recs.py::_provable_grade` takes the weakest cited grade as the ceiling,
/// and `insights/validator._grade_floor` does the same, fail-closed.
///
/// ## Why this file, and not another assertion in the grounding suite
///
/// `metric_info_grounding_test.dart` only ever calls
/// `weakestGrade(entry.value.notes)` — the static half. It could not have caught
/// this, and neither could reading the prose: the audit called it "the one
/// finding on this screen that no amount of prose care can catch". The thing
/// under test is the MERGE, so the merge is what this file exercises, through the
/// real sheet rather than by re-implementing it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/shared/format/note_grades.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';

/// Ids the server actually sends on the two paths above.
const String _contestedReserve = 'hr_reserve_vo2max';
const String _contestedAcwr = 'training_load_acwr';

void main() {
  test('the two payload ids this is about really are Contested', () {
    // If the corpus ever regrades them this file stops testing anything, and it
    // should say so loudly rather than passing on a vacuous premise.
    expect(kNoteGrades[_contestedReserve], 'Contested');
    expect(kNoteGrades[_contestedAcwr], 'Contested');
    expect(kGradeRank['Contested']!, lessThan(kGradeRank['Probable']!));
  });

  test('a Contested payload id drags the stamp down to Contested', () {
    // The VO₂max explainer's own notes are all Probable-or-better; the reserve
    // tier's payload adds `hr_reserve_vo2max`. The merged list is what the sheet
    // NAMES, so the merged list is what it may be graded against.
    final explainer = kMetricInfo['vo2max']!;
    expect(weakestGrade(explainer.notes), isNot('Contested'));

    final merged = <String>[
      ...explainer.notes,
      for (final id in const <String>['vo2max', _contestedReserve])
        if (!explainer.notes.contains(id)) id,
    ];
    expect(weakestGrade(merged), 'Contested');
  });

  testWidgets('the sheet stamps the grade of the merged list it renders', (
    tester,
  ) async {
    // Through the real widget: `_notes` is private, so the only honest way to
    // assert on it is to render the sheet and read what it drew.
    await _pump(tester, const MetricDetail(notes: <String>[_contestedReserve]));

    expect(find.text('CONTESTED'), findsOneWidget);
    expect(
      find.text('PROBABLE'),
      findsNothing,
      reason:
          'the stamp came from the explainer\'s static notes alone, so a '
          'Contested source is listed under a Probable grade',
    );
  });

  testWidgets('the ACWR path stamps Contested too', (tester) async {
    await _pump(tester, const MetricDetail(notes: <String>[_contestedAcwr]));
    expect(find.text('CONTESTED'), findsOneWidget);
  });

  testWidgets('an ordinary payload leaves the explainer grade alone', (
    tester,
  ) async {
    // The fix must not pull every sheet down. A payload citing only notes at or
    // above the explainer's own floor changes nothing.
    await _pump(tester, const MetricDetail(notes: <String>['vo2max']));
    final expected = weakestGrade(kMetricInfo['vo2max']!.notes)!;
    expect(find.text(expected.toUpperCase()), findsOneWidget);
  });

  testWidgets('a grade the server sent still wins over the computed one', (
    tester,
  ) async {
    // `DetailGrounding` renders `detail.grade ?? fallbackGrade`, and that order is
    // deliberate: the server has already applied `_provable_grade` over the notes
    // it cited. This fix changes the fallback, not the precedence.
    await _pump(
      tester,
      const MetricDetail(notes: <String>[_contestedReserve], grade: 'Emerging'),
    );
    expect(find.text('EMERGING'), findsOneWidget);
    expect(find.text('CONTESTED'), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, MetricDetail detail) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: MetricInfoDot('vo2max', detail: detail),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(MetricInfoDot));
  await tester.pumpAndSettle();
}
