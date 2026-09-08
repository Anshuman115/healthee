/// C2 · the honest fallback is an ANSWER, and the app used to draw it as nothing.
///
/// `insights/prompts.py::FALLBACK` — *"I can't ground that in our evidence base
/// right now, so I'd rather not guess…"* — is the sentence the whole honesty
/// layer exists to be able to give. It arrives with `validated: false,
/// refused: false`, and `GeneratedInsight.fromJson` blanked the text on exactly
/// that combination, so the card rendered empty.
///
/// The server has no branch that ships a model's unvalidated text:
/// `grounded._result` replaces the candidate with `FALLBACK`, a hard guardrail
/// returns its own fixed response, and a pre-LLM refusal returns a refusal
/// template. Three of our own strings and no fourth case. So the gate was not
/// protecting anything — it was deleting the product working correctly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/insights/generated_insight.dart';
import 'package:healthee/data/insights/insight_repository.dart';
import 'package:healthee/shared/insight_card.dart';

const String _fallbackText =
    "I can't ground that in our evidence base right now, so I'd rather not "
    'guess.';

Widget _card(GeneratedInsight insight) => ProviderScope(
  overrides: [
    generatedInsightProvider(
      'sleep',
      '',
    ).overrideWith((ref) async => insight),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(
      body: SingleChildScrollView(child: InsightCard(scope: 'sleep')),
    ),
  ),
);

Future<void> _open(WidgetTester tester, GeneratedInsight insight) async {
  await tester.pumpWidget(_card(insight));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Coach analysis'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('THE HONEST FALLBACK IS DRAWN, NOT BLANKED', (tester) async {
    await _open(
      tester,
      const GeneratedInsight(
        text: _fallbackText,
        citations: <String>[],
        validated: false,
      ),
    );

    expect(find.textContaining("can't ground that"), findsOneWidget);
    expect(
      find.textContaining('No grounded analysis available yet'),
      findsNothing,
      reason: 'an answer was rendered as an empty state',
    );
  });

  testWidgets('and it is framed as a fallback rather than a finding', (
    tester,
  ) async {
    await _open(
      tester,
      const GeneratedInsight(
        text: _fallbackText,
        citations: <String>[],
        validated: false,
      ),
    );

    expect(find.text(kUngroundedInsightNote), findsOneWidget);
  });

  testWidgets('a validated insight carries no such note', (tester) async {
    // The line must not appear on a normal answer, or it stops meaning anything.
    await _open(
      tester,
      const GeneratedInsight(
        text: 'Your sleep is steady [sleep_need_debt].',
        citations: <String>['sleep_need_debt'],
        validated: true,
      ),
    );

    expect(find.text(kUngroundedInsightNote), findsNothing);
    expect(find.textContaining('steady'), findsOneWidget);
  });

  testWidgets('genuinely empty text is still an empty state', (tester) async {
    // `metric_insight` returns `insight: ''` when the series is too thin. That
    // IS an absence, and it must keep saying so rather than drawing a blank card.
    await _open(
      tester,
      const GeneratedInsight(text: '', citations: <String>[], validated: true),
    );

    expect(find.textContaining('No grounded analysis available yet'), findsOneWidget);
  });
}
