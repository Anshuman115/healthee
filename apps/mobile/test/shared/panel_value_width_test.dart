/// `.panel-summary` is `space-between` over two `auto` boxes — not two halves.
///
/// `PanelValue` drew `Flexible(figure)` beside `Flexible(sentence)`. Both
/// default to `flex: 1`, so `RenderFlex` handed each **exactly half the row**,
/// and any figure wider than half — `12,480`, `7h 42m`, `1,284` — lost its last
/// glyphs to `TextOverflow.clip` at every phone width. It is the same defect
/// `ChapterHeading` was repaired for, in a second place, and it is fixed the
/// same way: the figure is measured and given what it needs, and the sentence
/// takes the true remainder.
///
/// ## What "what it needs" means, exactly
///
/// A browser gives a flex item `min-width: auto`, so a paragraph shrinks by
/// **wrapping** until it is as wide as its longest unbreakable run, and only
/// then does its neighbour give way. So the contract is:
///
/// ```text
///   figure width = min(figure's intrinsic width, row - sentence's min-content)
/// ```
///
/// and every case below asserts that number rather than a bound around it. The
/// old code returned `row / 2` regardless, which is what these cases are
/// measured against second.
///
/// ## Why the widths are named, and why 800 is not among them
///
/// The default `flutter_test` surface is 800 px wide, which is wider than any
/// phone this app runs on and wide enough that a 50/50 split still leaves room
/// for the whole figure. A test at 800 would have gone green against the broken
/// code. So every case pins a real width: 320 (what the prototype's own
/// `@media(max-width:359px)` rule targets), 360, 390 and 414.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// The phone widths this app is read on.
const List<double> kPhoneWidths = <double>[320, 360, 390, 414];

/// `Insets.lg` twice, plus a panel's own 18 px twice — the room a panel's
/// contents actually get on a phone of that width.
const double kPanelChrome = (15 + 18) * 2;

/// The right-hand sentence used throughout: real copy, and long enough to have
/// something to give up.
const String kSentence = 'vs a 9,000 median over 14 days';

/// A long figure with a sentence beside it: the case that clipped.
Widget _panel(double width, {String value = '12,480', String? unit}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width - kPanelChrome,
            child: PanelValue(value, unit: unit, context_: kSentence),
          ),
        ),
      ),
    );

double _widthOf(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// How wide the figure and its unit want to be.
double _wanted(String value, {String? unit}) {
  var wanted = _widthOf(value, TypeScale.panelValue);
  if (unit != null) {
    wanted += PanelValue.unitGap + _widthOf(unit, TypeScale.panelUnit);
  }
  return wanted;
}

/// The sentence's min-content width — its longest unbreakable run.
double get _sentenceFloor {
  final painter = TextPainter(
    text: const TextSpan(text: kSentence),
    textDirection: TextDirection.ltr,
  );
  painter.text = TextSpan(text: kSentence, style: TypeScale.panelContext);
  painter.layout();
  final floor = painter.minIntrinsicWidth;
  painter.dispose();
  return floor;
}

/// What the figure should be given on a row of [width].
double _expected(double width, String value, {String? unit}) {
  final available = width - kPanelChrome - PanelValue.gap;
  final wanted = _wanted(value, unit: unit);
  final room = available - _sentenceFloor;
  if (wanted < room) {
    return wanted;
  }
  return room < 0 ? 0 : room;
}

void main() {
  for (final width in kPhoneWidths) {
    final label = width.toInt();

    testWidgets('THE FIGURE IS NOT CAPPED AT HALF THE ROW — $label px', (
      tester,
    ) async {
      // The bug, named. `12,480` at 36 px wants more than half of every phone
      // row here, and half is precisely what it used to get.
      await tester.pumpWidget(_panel(width));
      await tester.pumpAndSettle();

      final available = width - kPanelChrome - PanelValue.gap;
      final box = tester.getSize(find.byKey(PanelValue.valueKey)).width;
      expect(
        _wanted('12,480'),
        greaterThan(available / 2),
        reason: 'the case is not exercising the bug at this width',
      );
      expect(
        box,
        greaterThan(available / 2),
        reason: 'the figure got half the row: the split is back',
      );
    });

    testWidgets('and it is given exactly what the CSS gives it — $label px', (
      tester,
    ) async {
      await tester.pumpWidget(_panel(width));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(PanelValue.valueKey)).width,
        moreOrLessEquals(_expected(width, '12,480'), epsilon: 0.5),
      );
    });

    testWidgets('a figure that fits is NOT CLIPPED AT ALL — $label px', (
      tester,
    ) async {
      // The whole point, at the widths it failed at: a figure the row can hold
      // beside its sentence comes out whole.
      const value = '92.4';
      await tester.pumpWidget(_panel(width, value: value));
      await tester.pumpAndSettle();

      expect(
        _wanted(value) + _sentenceFloor,
        lessThan(width - kPanelChrome - PanelValue.gap),
        reason: 'this figure does not fit at $label px; pick a shorter case',
      );
      expect(
        tester.getSize(find.byKey(PanelValue.valueKey)).width,
        moreOrLessEquals(_wanted(value), epsilon: 0.5),
      );
    });

    testWidgets('the unit travels inside the figure’s box — $label px', (
      tester,
    ) async {
      // The unit is drawn inside the figure's box, so a box measured for the
      // digits alone clips the unit instead of the number — the same bug
      // wearing a different symptom.
      const value = '92.4';
      await tester.pumpWidget(_panel(width, value: value, unit: 'h'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(PanelValue.valueKey)).width,
        moreOrLessEquals(_expected(width, value, unit: 'h'), epsilon: 0.5),
      );
    });

    testWidgets('and the sentence is never squeezed to nothing — $label px', (
      tester,
    ) async {
      // The other direction, which is what a naive "give the figure everything"
      // fix produces.
      await tester.pumpWidget(_panel(width));
      await tester.pumpAndSettle();

      final available = width - kPanelChrome - PanelValue.gap;
      final figure = tester.getSize(find.byKey(PanelValue.valueKey)).width;
      expect(available - figure, greaterThanOrEqualTo(_sentenceFloor - 0.5));
    });
  }

  testWidgets('a figure with no sentence takes the whole row', (tester) async {
    // `space-between` with one child is just that child. Nothing is reserved
    // for a sentence that is not there.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(width: 300, child: PanelValue('12,480')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(PanelValue.valueKey)).width,
      moreOrLessEquals(_wanted('12,480'), epsilon: 0.5),
    );
  });
}
