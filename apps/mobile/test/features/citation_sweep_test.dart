/// **Source chips are off every card face, and this is the gate that keeps them
/// off.**
///
/// The owner, for the second time: *"as i have stated previously to remove that
/// reference pills from everywhere it seems you forgot that"*. They were right,
/// and the reason they were right is the point of this file: the removal had been
/// done **per screen**, so every new card started with the chip again and one
/// missed shared widget (`shared/findings_section.dart`, rendered by Insights AND
/// Sleep) put them back on two screens at once.
///
/// A pass cannot hold a rule. So the first group **reads `lib/` itself** and names
/// the only files allowed to render a citation inline. `flutter analyze` cannot
/// see this — a `CitationRow` under a number is valid Dart — and no rendered
/// suite can either, because a screen nobody wrote a suite for is a screen with
/// no assertion on it.
///
/// ## The one way this sweep can do harm, and the half that guards it
///
/// **Grounding that becomes unreachable is a regression, not a tidy-up.** So the
/// second and third groups take each surface that lost a chip, prove the chip is
/// not painted on the card, and then **open the ⓘ and read the same ids back
/// out**. Both halves must hold: a suite that only checked the chip was gone
/// would pass on deleting the evidence, which is the outcome this product exists
/// to prevent.
///
/// `test/mutations.sh` drives it from both ends — a chip put back on the findings
/// card must fail here, and an ⓘ emptied of its citations must fail here too.
///
/// ## What this file deliberately does NOT sweep
///
/// The last group is the line the sweep must not cross, asserted by name so a
/// later tidy-up cannot quietly take one:
///
///   * **the prose itself** — `GroundedProse` must still draw the SENTENCE, with
///     the markers taken out and nothing else lost. It used to be exempt from
///     the chip rule instead, on the argument that a citation belongs beside the
///     claim it licenses; the exemption covered every card in the app, so the
///     chips came back under Sleep's analysis, every Actions rationale, Insights
///     and the coach. The owner reported it a third time and the exemption is
///     gone — but a sweep that answered by rendering nothing would be worse than
///     the defect, so what is asserted here is the prose surviving;
///   * **caveat signposts** — a caveated value still discloses in words, inside
///     the card that owns the number. Different rule, deliberately kept.
///
/// Today's own cards are enumerated one by one in
/// `test/features/card_provenance_test.dart`, which is the rendered half of the
/// same rule and holds the honesty sentences that stay on those cards.
///
/// The instruments — the source scan and the painted-rect probes — are in
/// `_citation_probe.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/features/profile/widgets/activity_level_field.dart';
import 'package:healthee/shared/findings_section.dart';
import 'package:healthee/shared/format/note_names.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/states/grounded_text.dart';

import '_citation_probe.dart';

/// The live findings card, carrying the two sources from the owner's screenshot.
const Finding kFinding = Finding(
  kind: 'pairwise_lag',
  metricA: 'hrv_sleep_avg',
  metricB: 'recovery_score',
  eventKind: null,
  description: 'Spearman(hrv_sleep_avg, recovery_score) = +0.72 over 105 days',
  effectSize: 0.72,
  effectMetric: 'rho',
  qValue: 0.0004,
  nSamples: 105,
  lagDays: 0,
  researchNoteIds: <String>['vo2max', 'weight_bmi_body_composition'],
);

/// The same card with nothing behind it — a finding the server sent no notes for.
const Finding kUncited = Finding(
  kind: 'pairwise_lag',
  metricA: 'hrv_sleep_avg',
  metricB: 'recovery_score',
  eventKind: null,
  description: '',
  effectSize: 0.4,
  effectMetric: 'rho',
  qValue: 0.04,
  nSamples: 30,
  lagDays: 0,
  researchNoteIds: <String>[],
);

/// One caveat, so the signpost has something to count.
const Disclosure kCaveat = Disclosure(
  reason: 'logged_weight_stale',
  message: 'Your last weigh-in is 41 days old.',
);

/// The profile control that used to carry a chip under it.
const ActivityLevelField kField = ActivityLevelField(
  value: 1,
  enabled: true,
  onChanged: _ignore,
);

void main() {
  group('the gate: no card surface may render a citation', () {
    test('NOTHING OUTSIDE THE ⓘ AND THE PROSE SURFACES DRAWS A CHIP', () {
      final offenders = <String>[
        for (final line in sourceLines())
          if (!kInlineGrounding.containsKey(line.path))
            if (kChip.hasMatch(line.text)) '${line.where}  ${line.text.trim()}',
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'a card’s sources belong in its ⓘ. Hand them to `MetricDetail` and '
            'let `MetricInfoDot` carry them: $offenders',
      );
    });

    test('NO CARD CARRIES A "Reference …" LABEL EITHER', () {
      final offenders = <String>[
        for (final line in sourceLines())
          if (kReferenceLabel.hasMatch(line.text))
            '${line.where}  ${line.text.trim()}',
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'a published cutoff is kept, in `MetricDetail.references`, under '
            '$kReferenceBlockLabel in the sheet: $offenders',
      );
    });

    test('MUTATION — the gate can actually see both of them', () {
      // A source scan that finds nothing looks identical whether the rule holds
      // or the pattern is broken.
      expect(kChip.hasMatch('        CitationRow(noteIds: notes),'), isTrue);
      expect(kChip.hasMatch('      const CitationRow(noteIds: [id]),'), isTrue);
      expect(
        kChip.hasMatch('/// resolved by `CitationRow` to a name.'),
        isFalse,
      );
      expect(
        kReferenceLabel.hasMatch(r"      note: 'Reference $cut',"),
        isTrue,
      );
      expect(
        kReferenceLabel.hasMatch('      label: "Reference: 150",'),
        isTrue,
      );
      expect(
        kReferenceLabel.hasMatch('    final references = detail;'),
        isFalse,
      );
    });

    test('the files allowed to ground inline still ground something', () {
      // Otherwise the allowlist rots into a list of files that stopped citing
      // anything, and the rule silently widens to cover nothing at all.
      for (final entry in kInlineGrounding.entries) {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: entry.key);
        expect(
          kChip.hasMatch(file.readAsStringSync()),
          isTrue,
          reason:
              '${entry.key} is allowed to cite inline (${entry.value}) and no '
              'longer cites at all',
        );
      }
    });
  });

  group('the findings card: swept, and still reachable', () {
    for (final width in kSweptWidths) {
      testWidgets('${width.toInt()}px — NO SOURCE IS PAINTED ON ITS FACE', (
        tester,
      ) async {
        await pumpAt(
          tester,
          width,
          const FindingsSection(findings: <Finding>[kFinding]),
        );

        final card = tester.getRect(find.byType(FindingsSection));
        expect(card.height, greaterThan(0), reason: 'the card drew nothing');
        expect(card.width, lessThanOrEqualTo(width));

        final painted = wordsOn(tester, card);
        for (final id in kFinding.researchNoteIds) {
          expect(
            painted,
            isNot(contains(noteName(id))),
            reason: '“${noteName(id)}” is painted inside $card',
          );
        }
        expect(
          painted.where((String said) => said.startsWith('Reference')),
          isEmpty,
        );
      });

      testWidgets('${width.toInt()}px — ITS ⓘ CARRIES THE SAME IDS', (
        tester,
      ) async {
        await pumpAt(
          tester,
          width,
          const FindingsSection(findings: <Finding>[kFinding]),
        );

        final card = tester.getRect(find.byType(FindingsSection));
        final dot = dotIn(find.byType(FindingsSection));
        expect(
          dot,
          findsOneWidget,
          reason:
              'a finding that lost its chips without gaining an ⓘ has lost its '
              'grounding, not moved it',
        );
        expectDotSits(tester, dot, card);

        await readIdsFromDot(tester, dot, kFinding.researchNoteIds, width);
      });
    }

    testWidgets('a finding citing nothing STILL HAS A SHEET, AND NO SOURCES', (
      tester,
    ) async {
      // **This reverses an older rule, on purpose.** It used to read *"a
      // finding citing nothing PAINTS no ⓘ at all"* — an ⓘ that opens an empty
      // sheet is a control promising grounding there is none of. The rule
      // stands; the sheet is no longer empty. The arithmetic moved behind this
      // dot, because five findings meant five inline `The statistic behind
      // this` disclosures stacked down the card.
      //
      // So what must be true is the honest half: the dot is there, the method
      // is behind it, and it names no source it does not have.
      await pumpAt(
        tester,
        360,
        const FindingsSection(findings: <Finding>[kUncited]),
      );

      final dot = dotIn(find.byType(FindingsSection));
      expect(dot, findsOneWidget);
      expect(tester.getRect(dot).isEmpty, isFalse);

      await tester.tap(dot);
      await tester.pumpAndSettle();
      expect(find.textContaining('rho = 0.40'), findsOneWidget);
      expect(
        find.textContaining('not that either one caused the other'),
        findsOneWidget,
      );
      for (final id in kFinding.researchNoteIds) {
        expect(
          find.text(noteName(id) ?? id),
          findsNothing,
          reason: 'this finding cites nothing; its sheet must name nothing',
        );
      }
    });

  });

  group('the activity-level field: swept, and still reachable', () {
    for (final width in kSweptWidths) {
      testWidgets('${width.toInt()}px — NO SOURCE UNDER THE CONTROL', (
        tester,
      ) async {
        await pumpAt(tester, width, kField);

        final field = tester.getRect(find.byType(ActivityLevelField));
        expect(field.height, greaterThan(0));
        expect(
          wordsOn(tester, field),
          isNot(contains(noteName('non_exercise_vo2max'))),
        );
      });

      testWidgets('${width.toInt()}px — ITS ⓘ CARRIES THE NOTE', (
        tester,
      ) async {
        await pumpAt(tester, width, kField);

        final field = tester.getRect(find.byType(ActivityLevelField));
        final dot = dotIn(find.byType(ActivityLevelField));
        expect(
          dot,
          findsOneWidget,
          reason:
              'five verbatim science labels with no reachable source are five '
              'sentences this app appears to have written itself',
        );
        expectDotSits(tester, dot, field);

        await readIdsFromDot(tester, dot, const <String>[
          'non_exercise_vo2max',
        ], width);
      });
    }
  });

  group('what the sweep may not take', () {
    for (final width in kSweptWidths) {
      testWidgets('${width.toInt()}px — GROUNDED PROSE KEEPS ITS SENTENCE', (
        tester,
      ) async {
        // The half a sweep can break by over-reaching: the marker comes out,
        // the SENTENCE does not. `GroundedProse` drawing nothing, or drawing
        // the raw string, would both pass a chip-count assertion.
        await pumpAt(
          tester,
          width,
          const GroundedProse(text: 'Take a short walk today [vo2max].'),
        );

        final painted = wordsOn(
          tester,
          tester.getRect(find.byType(GroundedProse)),
        );
        expect(painted, contains('Take a short walk today.'));
        expect(
          painted,
          isNot(contains(noteName('vo2max'))),
          reason:
              'prose used to draw its own chips, on every card in the app. The '
              'sources belong in the ⓘ of the card that draws the sentence.',
        );
        for (final line in painted) {
          expect(
            line,
            isNot(contains('[vo2max]')),
            reason: 'raw marker: $line',
          );
        }
      });

      testWidgets('${width.toInt()}px — A CAVEAT STILL SAYS SO, IN WORDS', (
        tester,
      ) async {
        await pumpAt(
          tester,
          width,
          CaveatNote(caveats: const <Disclosure>[kCaveat]),
        );

        final painted = wordsOn(
          tester,
          tester.getRect(find.byType(CaveatNote)),
        );
        expect(painted, contains(caveatHeadline(1)));
        expect(
          painted,
          contains('READ'),
          reason:
              'the signpost qualifies the number in its own card. It is not '
              'provenance and it does not move.',
        );
      });
    }
  });
}

/// A `ValueChanged` that does nothing — the field under test is read, not driven.
void _ignore(int? _) {}
