/// The stress card says nothing about how the owner FEELS, in any state.
///
/// It is called Stress again, which is what the strap calls it, what legacy
/// called it and what the owner asked for after it shipped as `AROUSAL · TODAY`.
/// The rename was a misreading: the four directives below govern **claims about
/// the value**, and none of them is about the card's name. What they forbid is
/// asserted here, on the card that carries the name.
///
/// `wearable_stress_validity` carries four SAFETY-CRITICAL directives, and all
/// four are about this one card:
///
///   * **D1** — never present the number as a psychological, emotional or mental
///     state. It is physiological arousal vs the owner's own baseline, and
///     the card's title is the strap's name for it, not a claim about it.
///   * **D2** — never infer mood or valence. "Stressed" and "excited" are
///     identical to this sensor.
///   * **D3** — a high or low value is non-specific (exertion, caffeine,
///     posture, illness and a bad signal all move it); never alarm on it.
///   * **D4** — it is unvalidated on our Huami/Zepp hardware; only heavily
///     caveated personal trends, never an absolute or clinical level.
///
/// Nothing in `insights/` can enforce these here. The note itself records that
/// D1–D4 are enforced by no output rule (#100), and a Dart string is invisible
/// to `insights/validator.py` in any case — which is exactly how the legacy
/// `metric_info` explainers shipped refuted science for months. So the
/// enforcement is this suite plus `test/mutations.sh`.
///
/// Every state is enumerated rather than sampled, in both themes. A rule that
/// holds on a full day of hours and breaks on a thin one is not a rule.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../shared/_chart_probe.dart';
import '_vitals_probe.dart';

void main() {
  group('the stress card — wearable_stress_validity D1–D4', () {
    /// Every state this card has.
    const states = <String, (List<double>, List<double>)>{
      'a full day of hours': (
        <double>[28, 41, 37, 55, 33, 29, 48, 36, 44, 31, 39, 42],
        <double>[],
      ),
      'three hours, the minimum for today': (<double>[28, 41, 37], <double>[]),
      'too few hours, so the fortnight instead': (
        <double>[28, 41],
        <double>[33, 36, 31, 39],
      ),
      'nothing at all': (<double>[], <double>[]),
    };

    Future<void> pumpState(
      WidgetTester tester,
      (List<double>, List<double>) state,
      ThemeData theme,
    ) async {
      await tester.pumpWidget(
        chartHost(
          StressCard(
            intraday: state.$1,
            daily: state.$2,
            reveals: RevealRegistry(),
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final theme in <String, ThemeData>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      for (final state in states.entries) {
        testWidgets('${theme.key} · ${state.key} — NAMES NO FEELING', (
          tester,
        ) async {
          await pumpState(tester, state.value, theme.value);

          final card = find.byType(StressCard);
          final rendered = textOf(tester, card).join(' · ').toLowerCase();
          for (final word in forbiddenOfStress) {
            expect(
              RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(rendered),
              isFalse,
              reason:
                  'the stress card said "$word" — D1/D2 forbid naming a state '
                  'or a band of one. What it rendered: $rendered',
            );
          }
          // The positive half, and the owner's own report: the card carries the
          // name his strap, his old app and every other screen use.
          expect(rendered, contains('stress'));
          expect(
            rendered,
            isNot(contains('arousal')),
            reason:
                'the metric was renamed out from under the owner once; the '
                'directives never asked for it',
          );
        });

        testWidgets('${theme.key} · ${state.key} — PAINTS NO VERDICT', (
          tester,
        ) async {
          await pumpState(tester, state.value, theme.value);

          final card = find.byType(StressCard);
          final colors = tester.element(card).colors;
          // D3: a high or low value is non-specific and must never alarm. This
          // card has no threshold, no band, and therefore nothing to colour.
          expect(
            paletteOf(
              tester,
              card,
              find.byType(HBars),
            ).intersection(verdictsOf(colors)),
            isEmpty,
            reason: 'a verdict colour reached the stress card',
          );
        });
      }
    }

    testWidgets('D3 — NO HOUR IS SINGLED OUT', (tester) async {
      // `HBars` emphasises its last bar by default, and emphasising the latest
      // hour of a signal the note calls non-specific is where a verdict starts.
      await pumpState(
        tester,
        (const <double>[28, 41, 37, 55, 33], const <double>[]),
        AppTheme.light,
      );

      final barColours = <int>{
        for (final call in paintedBy(tester, find.byType(HBars)))
          if (call.invocation.memberName == #drawRRect)
            for (final argument in call.invocation.positionalArguments)
              if (argument is Paint) argument.color.toARGB32(),
      };
      expect(
        barColours,
        hasLength(1),
        reason: 'two column colours means one hour was picked out',
      );
    });

    testWidgets('D4 — THE UNVALIDATED CAVEAT IS REACHABLE FROM THE CARD', (
      tester,
    ) async {
      // The score is unvalidated on Huami/Zepp hardware and the explainer says
      // so. The ⓘ is the only route to it, so the wiring IS the guarantee.
      await pumpState(
        tester,
        (const <double>[28, 41, 37, 55, 33], const <double>[]),
        AppTheme.light,
      );

      final dot = find.descendant(
        of: find.byType(StressCard),
        matching: find.byType(MetricInfoDot),
      );
      expect(
        dot,
        findsOneWidget,
        reason:
            'the ⓘ is the only route from this card to the sentence saying no '
            'consumer stress score is validated on Huami/Zepp hardware',
      );
      // And it opens the explainer that carries it. Grounding that text against
      // the note is `metric_info_grounding_test.dart`'s job; this is about the
      // door existing on THIS card.
      await tester.tap(dot, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('validated'),
        ),
        findsWidgets,
      );
    });
  });
}
