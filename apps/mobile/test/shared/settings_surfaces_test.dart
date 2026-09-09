/// `.card`, `.card.flush` and `.list-row`, measured against the prototype's CSS.
///
/// Every assertion here is a **painted** number — a laid-out size, a resolved
/// colour, a decoration actually handed to the render tree — because widget
/// presence is not a design. `chapter_heading_test.dart` records the reason at
/// length: a card that "contains a title and a rule" passed while every title
/// on the installed build was ellipsized.
///
/// Split from `settings_controls_test.dart` at the 400-line gate (Standards
/// section 1). The seam is the CSS's own: this file owns the **containers** a
/// supporting screen is made of, that one owns the **controls** inside them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/shared/v02/list_row.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

import '_settings_probe.dart';
import '_v02_harness.dart';

void main() {
  group('.card and .card.flush', () {
    testWidgets('a card is 22px round, surface, with one hairline', (
      tester,
    ) async {
      await pumpV02(tester, const PlainCard(child: SizedBox(height: 40)));

      final box = boxOf(tester, find.byType(Container).first);
      expect(radiusOf(box), PlainCard.radius);
      expect(groundOf(box), kColors.surface);
      expect(edgeOf(box)!.width, 1);
    });

    testWidgets('.card { padding: 20px } is what the child is inset by', (
      tester,
    ) async {
      const key = Key('card.child');
      await pumpV02(
        tester,
        const PlainCard(child: SizedBox(key: key, height: 40)),
      );

      final card = tester.getRect(find.byType(PlainCard));
      final child = tester.getRect(find.byKey(key));
      // The 1px border sits outside the padding — `box-sizing: border-box`.
      expect(child.left - card.left, closeTo(PlainCard.padding + 1, 0.01));
      expect(card.right - child.right, closeTo(PlainCard.padding + 1, 0.01));
    });

    testWidgets('a flush card draws the rule BETWEEN rows, never outside', (
      tester,
    ) async {
      await pumpV02(
        tester,
        const FlushCard(
          children: <Widget>[
            SizedBox(height: 30),
            SizedBox(height: 30),
            SizedBox(height: 30),
          ],
        ),
      );

      // `.list-row + .list-row` is a sibling selector: two rules for three
      // rows, and none above the first or below the last.
      final rules = find.descendant(
        of: find.byType(FlushCard),
        matching: find.byType(ColoredBox),
      );
      expect(rules, findsNWidgets(2));
    });

    testWidgets('A DIVIDER REACHES BOTH EDGES of the card it is in', (
      tester,
    ) async {
      // `.card .divider { margin-inline: -20px }` — the rule is a division of
      // the CARD, not a line drawn on its contents, and it only reads that way
      // if it clears the padding. Flutter has no negative padding, so this is
      // the substitution measured: an `OverflowBox` widened by 2 x 20, clipped
      // by the card's own rounded rect.
      await pumpV02(
        tester,
        const PlainCard(
          child: Column(
            children: <Widget>[
              SizedBox(height: 20),
              CardDivider(),
              SizedBox(height: 20),
            ],
          ),
        ),
      );

      final card = tester.getRect(find.byType(PlainCard));
      final rule = tester.getRect(
        find.descendant(
          of: find.byType(CardDivider),
          matching: find.byType(ColoredBox),
        ),
      );
      // The 1px border is the only thing between the rule and the card's edge.
      expect(rule.left - card.left, closeTo(1, 0.5));
      expect(card.right - rule.right, closeTo(1, 0.5));
      expect(rule.height, 1);
    });

    testWidgets('an EMPTY flush card draws nothing at all', (tester) async {
      // A bordered box with no rows in it is a control surface that controls
      // nothing.
      await pumpV02(tester, const FlushCard(children: <Widget>[]));
      expect(find.byType(Container), findsNothing);
    });
  });

  group('.list-row', () {
    testWidgets('is at least 60px tall and inset 16 / 11', (tester) async {
      await pumpV02(
        tester,
        ListRow(
          icon: SolarIconsOutline.refresh,
          title: 'Data & sync',
          onTap: () {},
        ),
      );

      final row = tester.getRect(find.byType(ListRow));
      expect(row.height, greaterThanOrEqualTo(ListRow.minHeight));

      final tile = tester.getRect(find.byIcon(SolarIconsOutline.refresh));
      // 16 of padding, then a 34 tile — the compact row. The CSS's 20/40 sized
      // a row whose subtitle wrapped to two lines; these rows carry a value
      // opposite the title instead, and nine of them at 72 ran a section past
      // the fold.
      expect(tile.center.dx - row.left, closeTo(16 + 34 / 2, 0.5));
    });

    testWidgets('THE TITLE TAKES THE ROW, and the subtitle stays on one line', (
      tester,
    ) async {
      // `Flexible` beside another flexible child splits the free space and
      // ellipsizes the title; `Expanded` between two fixed-size children takes
      // the remainder. This is that difference, measured.
      await pumpV02(
        tester,
        ListRow(
          icon: SolarIconsOutline.chartSquare,
          title: 'Instruments',
          subtitle:
              'Every baseline, and every stream this phone read — each saying '
              'how it was measured.',
          onTap: () {},
        ),
      );

      final row = tester.getRect(find.byType(ListRow));
      final subtitle = tester.getRect(find.textContaining('Every baseline'));
      // 16 padding + 34 tile + 12 gap on the left; 12 gap + 16 chevron + 16 on
      // the right. The subtitle fills exactly what is left.
      expect(subtitle.left - row.left, closeTo(16 + 34 + 12, 0.5));
      expect(row.right - subtitle.right, closeTo(16 + 16 + 12, 0.5));
      // **One line, and that is the change.** The CSS sets `white-space:
      // normal` and the subtitle used to wrap; a sentence running to three
      // lines made a row as tall as a card, which is what the compaction pass
      // was about. A row is one row, and the sentence ellipses.
      expect(subtitle.height, lessThan(24));
    });

    testWidgets('a row that leads nowhere draws NO chevron', (tester) async {
      await pumpV02(
        tester,
        const ListRow(icon: SolarIconsOutline.refresh, title: 'Data & sync'),
      );
      expect(find.byIcon(SolarIconsOutline.altArrowRight), findsNothing);
    });

    testWidgets('a row that DECLARES a tone takes that family', (tester) async {
      await pumpV02(
        tester,
        const ListRow(
          icon: SolarIconsOutline.moonSleep,
          title: 'Sleep',
          tone: Tone.sleep,
        ),
        tone: Tone.sleep,
      );

      final tile = boxOf(
        tester,
        find
            .ancestor(
              of: find.byIcon(SolarIconsOutline.moonSleep),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(groundOf(tile), kHues.sleepSoft);
      expect(
        tester.widget<Icon>(find.byIcon(SolarIconsOutline.moonSleep)).color,
        kHues.sleep,
      );
    });

    testWidgets('A ROW THAT DECLARES NONE IS CHROME, IN THE OWNER’S ACCENT', (
      tester,
    ) async {
      // **The reason `IconTile.chrome` exists.** A settings row is not a
      // reading. With no tone of its own it resolved the enclosing scope — and
      // outside one, `Tone.fitness`, the `:root` default — so every row on
      // every settings screen wore the colour of recovery and VO₂max. A phone
      // set to Amber showed an amber tab bar and twelve green settings rows.
      await pumpV02(
        tester,
        const ListRow(icon: SolarIconsOutline.moonSleep, title: 'Sleep'),
        tone: Tone.sleep,
      );

      final tile = boxOf(
        tester,
        find
            .ancestor(
              of: find.byIcon(SolarIconsOutline.moonSleep),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(groundOf(tile), isNot(kHues.sleepSoft));
      expect(
        tester.widget<Icon>(find.byIcon(SolarIconsOutline.moonSleep)).color,
        isNot(kHues.sleep),
        reason: 'chrome follows the accent, never the surrounding family',
      );
    });
  });
}
