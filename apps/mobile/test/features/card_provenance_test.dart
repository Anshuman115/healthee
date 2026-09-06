/// Method and provenance are OFF the cards — and reachable from every one.
///
/// The owner, twice: *"that reference pill can we remove those from cards
/// please info sheets are for that"* and *"all these unnecessary Sleep
/// regularity long text and other texts in pills in evrycard"*.
///
/// This suite is written as a pair of claims that must BOTH hold, because
/// either one alone is a worse screen than the one we started with:
///
///   1. no card draws a `Reference …` label or a source chip on its face;
///   2. every card that lost one exposes it through a reachable ⓘ.
///
/// The second half is the one that matters. A claim whose grounding becomes
/// unreachable is a regression, not a tidy-up — so the cards are **enumerated**
/// rather than sampled, each ⓘ is opened, and the sources are read out of the
/// sheet. `test/mutations.sh` empties the sheet's citation row on purpose and
/// requires this file to notice.
///
/// The third group is the line the sweep must not cross: the sentences that
/// qualify a number rather than teach about it stay on the card that owns the
/// number, and each is asserted **by name** so a later tidy-up cannot quietly
/// take one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/v02/day_panels.dart';
import 'package:healthee/features/today/v02/recovery_panel.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/v02/panel_head.dart';

import '_today_host.dart';

/// Every card on Today that carries grounding, and what its ⓘ must hold.
///
/// A table rather than a handful of spot checks: the failure this guards
/// against is one card being missed, and a sample cannot see that.
const Map<String, List<String>> kCardCitations = <String, List<String>>{
  'Recovery, explained': <String>['recovery_readiness'],
  'Sleep health, beyond duration': <String>[
    'sleep_health_score_multidim',
    'sleep_regularity_index',
  ],
  'Effort in context': <String>['cardio_load_trimp'],
  'Active minutes': <String>['mvpa_minutes_mortality', 'cadence_intensity'],
  'Strength': <String>['strength_training_mortality'],
  'Cardiorespiratory fitness': <String>[
    'vo2max_fitness_mortality',
    'submaximal_vo2max',
  ],
};

/// The references that used to be pills on a card's face.
const Map<String, String> kCardReferences = <String, String>{
  'Sleep health, beyond duration': 'reference',
  'Active minutes': 'min/week',
  'Strength': 'min/week',
  'Cardiorespiratory fitness': 'Age/sex reference',
};

/// The sentences that must SURVIVE on the card, named one by one.
///
/// Each is here because deleting it would leave a number unqualified, not
/// merely unexplained — see the comment at each site in the panels.
const List<String> kHonestySentencesKept = <String>[
  // Clinical routing: a symptom outranks the score above it.
  kRecoveryPriorityNote,
  // Instrument naming: a modelled figure beside measured ones.
  kEnergyModelledNote,
  // Arithmetic invisible in the figure above it.
  'vigorous ×2',
  // A definition: this figure is not part of the total beside it.
  'tracked separately',
  // What the ± is NOT.
  'error magnitude is not a confidence interval',
  // Which reading the cell holds.
  'Overnight average',
];

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(420, 14000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();
  }

  group('the card surfaces', () {
    testWidgets('NO CARD DRAWS A SOURCE CHIP', (tester) async {
      await pump(tester);

      expect(
        find.byType(CitationRow),
        findsNothing,
        reason:
            'the readable citation names at a card’s foot are provenance, and '
            'the ⓘ is where the owner asked provenance to live',
      );
    });

    testWidgets('NO CARD DRAWS A REFERENCE LABEL', (tester) async {
      await pump(tester);

      final offenders = <String>[
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          if (_says(text) case final String said)
            if (said.contains('Reference ') || said.contains('Reference:'))
              said,
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'these are still on a card face: $offenders',
      );
    });
  });

  group('and every one of them is reachable through an ⓘ', () {
    for (final entry in kCardCitations.entries) {
      testWidgets('${entry.key} EXPOSES ITS SOURCES', (tester) async {
        await pump(tester);
        await reveal(tester, find.text(entry.key));

        final dot = find.descendant(
          of: find.ancestor(
            of: find.text(entry.key),
            matching: find.byType(PanelHead),
          ),
          matching: find.byType(MetricInfoDot),
        );
        expect(
          dot,
          findsOneWidget,
          reason:
              'a card that lost its citations without gaining an ⓘ has lost '
              'them, not moved them',
        );

        await tester.tap(dot);
        await tester.pumpAndSettle();

        final rows = tester.widgetList<CitationRow>(find.byType(CitationRow));
        expect(rows, isNotEmpty, reason: 'the sheet carries no sources at all');
        final ids = <String>[for (final row in rows) ...row.noteIds];
        for (final id in entry.value) {
          expect(
            ids,
            contains(id),
            reason: '$id is cited by ${entry.key} and is not in its sheet',
          );
        }
      });
    }

    for (final entry in kCardReferences.entries) {
      testWidgets('${entry.key} KEEPS ITS REFERENCE, IN THE SHEET', (
        tester,
      ) async {
        await pump(tester);
        await reveal(tester, find.text(entry.key));

        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text(entry.key),
              matching: find.byType(PanelHead),
            ),
            matching: find.byType(MetricInfoDot),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(entry.value),
          findsWidgets,
          reason:
              'a published cutoff with no source is a number this app made up',
        );
        expect(find.text(kReferenceBlockLabel), findsOneWidget);
      });
    }
  });

  group('the sentences that qualify a number stay on it', () {
    for (final sentence in kHonestySentencesKept) {
      testWidgets('KEPT ON THE CARD: "$sentence"', (tester) async {
        await pump(tester);
        expect(
          find.textContaining(sentence),
          findsWidgets,
          reason:
              'this qualifies the figure beside it. Removing it to reduce '
              'clutter is the one way this change makes the screen worse.',
        );
      });
    }

    testWidgets('A CAVEATED VALUE STILL SAYS SO, IN WORDS, IN ITS OWN CARD', (
      tester,
    ) async {
      await pump(tester);

      // `CaveatNote`'s counted signpost. Not an asterisk, not a colour — the
      // owner could not read either.
      expect(find.textContaining('Caveated —'), findsWidgets);
      expect(find.text('READ'), findsWidgets);
    });
  });
}

/// The text a `Text` actually says, whether it was built from a string or a span.
String? _says(Text text) => text.data ?? text.textSpan?.toPlainText();
