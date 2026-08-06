/// The widgets ported from `ui.dart` — measured, not merely rendered.
///
/// It would be easy to test only that these render. What is actually
/// load-bearing is their **geometry**: a module that pads at 13 instead of 14,
/// an eyebrow at the wrong tracking, a progress bar whose fill ignores its
/// reveal. Every one of those is invisible in a diff and visible on a phone.
///
/// The verdict colours get a **mutation**: asserting that a delta of -4 draws
/// `alert` means nothing unless the same table also proves `good: true` flips
/// it. Legacy's polarity flag is the thing that would silently invert.
///
/// The pure values these lean on — the corner, the curve, the type roles — are
/// in `instrument_tokens_test.dart`; the skeletons are in `skeletons_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/instrument/h_delta_badge.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/section_heading.dart';

const HealtheeColors _light = HealtheeColors.light();
const InstrumentHues _hues = InstrumentHues.light();

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
);

/// A host with NO width constraint, for widgets that size themselves.
Widget _tightHost(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style!;

void main() {
  group('HTap', () {
    testWidgets('a null onTap is a PASS-THROUGH, with no detector at all', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const HTap(child: Text('quiet'))));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(HTap),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('SCALES TO 97.5% UNDER THE FINGER, and back', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(HTap(onTap: () => taps++, child: const Text('press'))),
      );
      await tester.pumpAndSettle();

      double scale() => tester
          .widget<AnimatedScale>(find.byType(AnimatedScale))
          .scale;
      expect(scale(), 1);

      final gesture = await tester.startGesture(tester.getCenter(find.text('press')));
      await tester.pump();
      expect(scale(), 0.975, reason: 'legacy’s `.tap:active { scale(0.975) }`');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale(), 1);
      expect(taps, 1);
    });
  });

  group('HDeltaBadge', () {
    Future<Color> colourOf(WidgetTester tester, num value, {bool? good}) async {
      await tester.pumpWidget(_host(HDeltaBadge(value, good: good)));
      await tester.pumpAndSettle();
      return _styleOf(tester, '${value > 0 ? '+' : ''}$value').color!;
    }

    testWidgets('UP IS GREEN AND DOWN IS RED — legacy’s default polarity', (
      tester,
    ) async {
      expect(await colourOf(tester, 4), _light.fav);
      expect(await colourOf(tester, -4), _light.alert);
    });

    testWidgets('MUTATION — `good` OVERRIDES THE SIGN, in both directions', (
      tester,
    ) async {
      // The assertion above passes for a badge that ignores `good` entirely.
      // This one does not. Note what `good` means: legacy's `good ?? up` asks
      // "is THIS change favourable", not "is up favourable" — so a fall that is
      // good news is `good: true`, and a rise that is bad news is `good: false`.
      expect(await colourOf(tester, 4, good: false), _light.alert);
      expect(await colourOf(tester, -4, good: true), _light.fav);
    });

    testWidgets('ZERO IS NEITHER — no arrow, no verdict colour', (tester) async {
      await tester.pumpWidget(_host(const HDeltaBadge(0)));
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsNothing, reason: 'no direction to point in');
      expect(_styleOf(tester, '0').color, _light.ink3);
    });

    testWidgets('the direction is in the SEMANTICS, not only in the colour', (
      tester,
    ) async {
      // Colour is the only thing carrying the verdict on screen, and a screen
      // reader cannot see it.
      await tester.pumpWidget(_host(const HDeltaBadge(-4, good: true)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byType(Text)).semanticsLabel,
        '-4, better',
      );
    });
  });

  group('HProgressBar', () {
    Future<double> fillWidth(WidgetTester tester, double value, double progress) async {
      await tester.pumpWidget(
        _host(HProgressBar(value: value, progress: progress)),
      );
      await tester.pumpAndSettle();
      return tester
          .getSize(find.descendant(
            of: find.byType(HProgressBar),
            matching: find.byType(Container),
          ).last)
          .width;
    }

    testWidgets('THE FILL IS PROPORTIONAL, AND THE REVEAL SCALES IT', (
      tester,
    ) async {
      expect(await fillWidth(tester, 100, 1), closeTo(320, 0.01));
      expect(await fillWidth(tester, 50, 1), closeTo(160, 0.01));
      // Half revealed, half the value: a quarter of the track.
      expect(await fillWidth(tester, 50, 0.5), closeTo(80, 0.01));
    });

    testWidgets('a value past the top of the scale does not overflow the track', (
      tester,
    ) async {
      expect(await fillWidth(tester, 260, 1), closeTo(320, 0.01));
    });

    testWidgets('the bar is legacy’s 5 px, and fully pilled', (tester) async {
      await tester.pumpWidget(
        _host(const HProgressBar(value: 40, progress: 1)),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(HProgressBar)).height, 5);
    });
  });

  group('HIconBadge and HAvatar', () {
    testWidgets('the badge is legacy’s 40 px at 18% of its own colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _tightHost(HIconBadge(Icons.bedtime_outlined, color: _hues.sleep)),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(HIconBadge)), const Size(40, 40));
      final box = tester.widget<Container>(find.byType(Container));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color!.a, closeTo(0.18, 0.005));
      expect(tester.widget<Icon>(find.byType(Icon)).size, 20);
    });

    testWidgets('the avatar is 38 px of accent with the letter at 42%', (
      tester,
    ) async {
      await tester.pumpWidget(_tightHost(const HAvatar('A')));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(HAvatar)), const Size(38, 38));
      expect(_styleOf(tester, 'A').fontSize, closeTo(38 * 0.42, 1e-9));
      expect(_styleOf(tester, 'A').color, _light.onAccent);
    });
  });

  group('InstrumentModule', () {
    testWidgets('LEGACY’S 14 PX PADDING, AND NO IDENTITY DOT', (tester) async {
      await tester.pumpWidget(
        _host(
          InstrumentModule(
            label: 'Sleep',
            tag: _hues.sleep,
            children: const <Widget>[ModuleValue(value: '7:50', unit: 'hrs')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(InstrumentModule),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.all(14));

      // THE DOT IS GONE — owner-directed, 2026-08-06: *"can we remove that
      // colored dots from cards"*. Legacy draws a 6 px circle in the metric's
      // hue at the top right of every module and this port drew it too. The hue
      // is still DECLARED (`tag`, asserted in `moved_card_tags_test.dart`) and
      // still tints the module's chart; nothing paints it as a mark.
      final circles = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (container) =>
                (container.decoration as BoxDecoration?)?.shape ==
                BoxShape.circle,
          );
      expect(circles, isEmpty, reason: 'the identity dot is not drawn');
      expect(
        tester.widget<InstrumentModule>(find.byType(InstrumentModule)).tag,
        _hues.sleep,
        reason: 'the hue is still the module’s declared identity',
      );
    });

    testWidgets('the eyebrow is uppercase on screen and NOT to a screen reader', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const ModuleLabel('Resting HR')));
      await tester.pumpAndSettle();

      expect(find.text('RESTING HR'), findsOneWidget);
      expect(_styleOf(tester, 'RESTING HR').fontSize, 9);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Resting HR'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the value is 27 px with its unit at 10 on the baseline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ModuleValue(value: '7:50', unit: 'hrs')),
      );
      await tester.pumpAndSettle();
      expect(_styleOf(tester, '7:50').fontSize, 27);
      expect(_styleOf(tester, 'hrs').fontSize, 10);
      expect(_styleOf(tester, 'hrs').color, _light.ink3);
    });

    testWidgets('a module that opens PRESSES, it does not ripple', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _host(
          InstrumentModule(
            label: 'Sleep',
            tag: _hues.sleep,
            onOpen: () => opened++,
            children: const <Widget>[Text('7:50')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InkWell), findsNothing, reason: 'legacy scales, not ripples');
      expect(find.byType(HTap), findsOneWidget);
      await tester.tap(find.byType(InstrumentModule));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('the foot is legacy’s 9 px at 0.04 em, 8 px above', (tester) async {
      await tester.pumpWidget(_host(const ModuleFoot('goal 10,000 · 84%')));
      await tester.pumpAndSettle();
      final style = _styleOf(tester, 'GOAL 10,000 · 84%');
      expect(style.fontSize, 9);
      expect(style.letterSpacing, closeTo(0.36, 1e-9));
      expect(
        tester.widget<Padding>(find.byType(Padding).first).padding,
        const EdgeInsets.only(top: 8),
      );
    });
  });

  group('SectionHeading', () {
    testWidgets('IS A 23 PX TITLE IN SENTENCE CASE, as legacy draws it', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const SectionHeading('Measured at rest')));
      await tester.pumpAndSettle();

      // The rebuild used to uppercase these over a hairline rule. Legacy does
      // neither.
      expect(find.text('Measured at rest'), findsOneWidget);
      expect(find.text('MEASURED AT REST'), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(_styleOf(tester, 'Measured at rest').fontSize, 23);
    });

    testWidgets('the action renders as legacy’s `LABEL →` in the accent', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        _host(SectionHeading('Suggested today', onSeeAll: () => opened++)),
      );
      await tester.pumpAndSettle();

      expect(_styleOf(tester, 'SEE ALL →').color, _light.accent);
      await tester.tap(find.text('SEE ALL →'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });
}
