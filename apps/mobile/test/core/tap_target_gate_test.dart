/// Every tappable control declares how it hit-tests, and the links are 44 px.
///
/// ## The defect this closes
///
/// `GestureDetector` defaults to `HitTestBehavior.deferToChild`: only the
/// PAINTED pixels of the child answer a touch. A control whose child is bare
/// text, a bare glyph, or a `Container` with no fill therefore has a tap target
/// the size of its ink — and every bit of padding, every `minHeight`, every
/// comfortable-looking gap around it is transparent to a finger.
///
/// It shipped four times. `HLinkButton` documented `.text-button { min-height:
/// 44px }`, sized its box to 44, and left 24 of those pixels dead — the owner
/// reported the two links on the sign-in screen as "very difficult to press".
/// `PanelHead`'s compact action was a 16 px glyph. `ThemeOptions` paints its
/// ground only when *chosen*, so the option you are always trying to tap was the
/// one that painted nothing. `ChapterNav`'s buttons are a border with no fill —
/// a control with a hole through the middle.
///
/// None of that is visible in a screenshot, and none of it fails a widget test
/// that taps `find.text(...)`, because tapping the text is exactly what still
/// works. So the gate is on the source, the same way
/// `test/data/redirect_policy_test.dart` reads `lib/` for a dio built without
/// `followRedirects`.
///
/// **A behaviour that is wrong is still declared**, and that is the point: the
/// rule is not "always be opaque", it is "say which, on purpose". `deferToChild`
/// is right for a control that must let taps through to something behind it, and
/// writing it down is what turns that into a decision.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/shared/v02/buttons.dart';

/// Every `.dart` file under `lib/`.
Iterable<File> _libFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

void main() {
  test('EVERY GestureDetector WITH A TAP DECLARES ITS HIT-TEST BEHAVIOUR', () {
    final offenders = <String>[];
    for (final file in _libFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('GestureDetector(')) {
          continue;
        }
        // The constructor's arguments, however they are wrapped. Ten lines is
        // past the longest of these in this codebase and short enough that the
        // next widget's arguments cannot be mistaken for this one's.
        final window = lines.skip(i).take(10).join('\n');
        final tappable =
            window.contains('onTap:') || window.contains('onLongPress:');
        if (tappable && !window.contains('behavior:')) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these declare no hit-test behaviour, so their tap target is only '
          'the pixels their child paints — padding and minHeight included are '
          'dead to a finger: $offenders',
    );
  });

  test('the sweep is actually reading the source', () {
    // The guard on the guard. A scan that found no files would report a clean
    // result forever, which is how this kind of gate goes green while
    // protecting nothing.
    final files = _libFiles().toList();
    expect(files.length, greaterThan(200));
    expect(
      files.where((f) => f.readAsStringSync().contains('GestureDetector(')),
      isNotEmpty,
      reason: 'no GestureDetector found at all — the sweep is looking wrong',
    );
  });

  testWidgets('A LINK IS TAPPABLE IN ITS WHITESPACE, NOT ONLY ON ITS LETTERS', (
    tester,
  ) async {
    // The behavioural half. The source gate above proves a behaviour is
    // DECLARED; this proves the declared one produces a target you can hit —
    // by pressing a point that is inside the control and outside the ink.
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: HLinkButton(label: 'Create an account', onPressed: () => taps++),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(HLinkButton));
    // 44 as a LITERAL, not `HLinkButton.minHeight`. Against the constant this was
    // a tautology — the box is sized by that same constant, so shrinking it moved
    // both sides of the comparison and the assertion held at any size. Caught by
    // `mutations.sh 'the 44 px link constraint is dropped'`, which survived. The
    // number comes from the prototype's `.text-button { min-height: 44px }` and
    // from the platform minimum, so the test owns it independently.
    expect(
      box.height,
      greaterThanOrEqualTo(44.0),
      reason: '.text-button { min-height: 44px }',
    );

    // Two pixels below the top edge: inside the control, well above the text,
    // and dead to a finger before `HitTestBehavior.opaque`.
    await tester.tapAt(Offset(box.center.dx, box.top + 2));
    await tester.pump();
    expect(taps, 1, reason: 'the padding above the label must accept a tap');

    await tester.tapAt(Offset(box.center.dx, box.bottom - 2));
    await tester.pump();
    expect(taps, 2, reason: 'and the padding below it');
  });
}
