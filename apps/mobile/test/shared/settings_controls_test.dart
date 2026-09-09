/// `.button`, `.switch`, `.theme-option`, `.notice` and `.badge`, measured.
///
/// The controls half of the supporting screens' primitives; the containers are
/// in `settings_surfaces_test.dart`, split at the 400-line gate (Standards
/// section 1). Same discipline: painted geometry and resolved colour, never
/// widget presence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/notices.dart';
import 'package:healthee/shared/v02/theme_options.dart';
import 'package:healthee/shared/v02/toggle_row.dart';
import 'package:solar_icons/solar_icons.dart';

import '_settings_probe.dart';
import '_v02_harness.dart';

void main() {
  group('.button', () {
    testWidgets('is 48px tall, 16px round, on the accent', (tester) async {
      await pumpV02(tester, HButton(label: 'Save profile', onPressed: () {}));

      final box = boxOf(tester, find.byType(Container).first);
      expect(radiusOf(box), HButton.radius);
      expect(groundOf(box), kColors.accent);
      expect(
        tester.getRect(find.byType(HButton)).height,
        greaterThanOrEqualTo(HButton.minHeight),
      );
      expect(edgeOf(box), isNull);
    });

    testWidgets('.secondary is surface on a --rule edge', (tester) async {
      await pumpV02(
        tester,
        HButton(
          label: 'Sign out',
          kind: HButtonKind.secondary,
          onPressed: () {},
        ),
      );

      final box = boxOf(tester, find.byType(Container).first);
      expect(groundOf(box), kColors.surface);
      expect(edgeOf(box)!.color, kColors.rule);
    });

    testWidgets('a disabled button dims the WHOLE control, not its label', (
      tester,
    ) async {
      // `button:disabled { opacity: .45 }` is on the button. Dimming the words
      // alone leaves a full-strength accent slab advertising a dead action.
      await pumpV02(tester, const HButton(label: 'Save', onPressed: null));

      expect(
        tester.widget<Opacity>(find.byType(Opacity).first).opacity,
        HButton.disabledOpacity,
      );
    });

    testWidgets('IT SPANS THE ROW, so two of them cannot overflow it', (
      tester,
    ) async {
      // The failure this replaces: two labels in a `Row` were 110px wider than
      // a 420px phone, and every suite pumped 800 and saw nothing.
      await pumpV02(
        tester,
        HButton(label: 'Use a different server', onPressed: () {}),
      );
      expect(tester.getRect(find.byType(HButton)).width, kContentWidth);
    });
  });

  group('.switch', () {
    testWidgets('is 42 x 26 with an 18px knob at rest 3px in', (tester) async {
      await pumpV02(tester, const HSwitch(value: false), width: null);

      final track = tester.getRect(find.byType(HSwitch));
      expect(track.width, HSwitch.width);
      expect(track.height, HSwitch.height);

      // **Measured from the PADDING edge, not the border box.** `::after` is
      // absolutely positioned inside a `position: relative` element, so CSS
      // measures its `left: 3px` from inside the 1px border — and Flutter's
      // `Border` insets a `Container`'s child by exactly the same 1px. The two
      // agree; an assertion taken from the outer edge would be off by the
      // border and would have been "fixed" by moving the knob.
      final knob = tester.getRect(find.byType(DecoratedBox).last);
      expect(knob.width, HSwitch.knob);
      expect(knob.left - track.left, closeTo(HSwitch.inset + 1, 0.01));
    });

    testWidgets('ON, the knob has travelled exactly 16px', (tester) async {
      await pumpV02(tester, const HSwitch(value: true), width: null);
      await tester.pumpAndSettle();

      final track = tester.getRect(find.byType(HSwitch));
      final knob = tester.getRect(find.byType(DecoratedBox).last);
      // The border again — see the rest-position case above.
      expect(
        knob.left - track.left,
        closeTo(HSwitch.inset + HSwitch.travel + 1, 0.01),
      );
    });

    testWidgets('THE WHOLE ROW is the hit target, not the 42px control', (
      tester,
    ) async {
      // 42 x 26 is under any tap-target guidance, and a person taps the words.
      var on = false;
      await pumpV02(
        tester,
        ToggleRow(
          title: 'Only while charging',
          body: 'Save background work for when plugged in.',
          value: on,
          onChanged: (value) => on = value,
        ),
      );

      await tester.tap(find.text('Only while charging'));
      expect(on, isTrue);
    });
  });

  group('.theme-option', () {
    testWidgets('the chosen tile takes the accent edge AND ground', (
      tester,
    ) async {
      await pumpV02(
        tester,
        ThemeOptions<int>(
          selected: 1,
          onSelected: (_) {},
          options: const <ThemeOption<int>>[
            ThemeOption<int>(
              value: 0,
              icon: SolarIconsOutline.sun,
              label: 'Light',
            ),
            ThemeOption<int>(
              value: 1,
              icon: SolarIconsOutline.moon,
              label: 'Dark',
            ),
          ],
        ),
      );

      final chosen = boxOf(
        tester,
        find
            .ancestor(of: find.text('Dark'), matching: find.byType(Container))
            .first,
      );
      expect(groundOf(chosen), kColors.accentSoft);
      expect(edgeOf(chosen)!.color, kColors.accent);

      final other = boxOf(
        tester,
        find
            .ancestor(of: find.text('Light'), matching: find.byType(Container))
            .first,
      );
      expect(groundOf(other), isNull);
      expect(edgeOf(other)!.color, kColors.rule);
    });

    testWidgets('the two tiles are equal thirds of the row', (tester) async {
      await pumpV02(
        tester,
        ThemeOptions<int>(
          selected: 0,
          onSelected: (_) {},
          options: const <ThemeOption<int>>[
            ThemeOption<int>(
              value: 0,
              icon: SolarIconsOutline.sun,
              label: 'Light',
            ),
            ThemeOption<int>(
              value: 1,
              icon: SolarIconsOutline.moon,
              label: 'Dark',
            ),
            ThemeOption<int>(
              value: 2,
              icon: SolarIconsOutline.settings,
              label: 'System',
            ),
          ],
        ),
      );

      final widths = <double>[
        for (final String label in <String>['Light', 'Dark', 'System'])
          tester
              .getRect(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .width,
      ];
      expect(widths[0], closeTo(widths[1], 0.01));
      expect(widths[1], closeTo(widths[2], 0.01));
      final total = widths.reduce((a, b) => a + b) + ThemeOptions.gap * 2;
      expect(total, closeTo(kContentWidth, 0.01));
    });
  });

  group('.notice and .badge', () {
    testWidgets('a plain notice is untinted — the red is NOT spent here', (
      tester,
    ) async {
      // `alert` is the illness flag and the only red in the product. A sign-in
      // or pairing failure is not a fact about the owner's body.
      await pumpV02(
        tester,
        const HNotice(title: 'Not confirmed yet', body: 'A scan only listens.'),
      );

      final box = boxOf(tester, find.byType(Container).first);
      expect(groundOf(box), kColors.surface2);
      expect(groundOf(box), isNot(kColors.alertSoft));
      expect(radiusOf(box), HNotice.radius);
    });

    testWidgets('an error notice drops its border and takes the red', (
      tester,
    ) async {
      await pumpV02(
        tester,
        const HNotice(
          title: 'Your server is out of reach',
          body: 'Saved readings are still available.',
          kind: NoticeKind.error,
        ),
      );

      final box = boxOf(tester, find.byType(Container).first);
      expect(groundOf(box), kColors.alertSoft);
      expect(edgeOf(box), isNull);
    });

    testWidgets('the badge pairs match the CSS classes', (tester) async {
      for (final (BadgeKind kind, Color ground, Color mark)
          in <(BadgeKind, Color, Color)>[
            (BadgeKind.plain, kColors.surface2, kColors.ink2),
            (BadgeKind.good, kColors.favSoft, kColors.fav),
            (BadgeKind.warm, kColors.unfSoft, kColors.unf),
            (BadgeKind.accent, kColors.accentSoft, kColors.accent),
          ]) {
        await pumpV02(tester, HBadge('Available', kind: kind), width: null);
        final box = boxOf(tester, find.byType(Container).first);
        expect(groundOf(box), ground, reason: '$kind ground');
        expect(radiusOf(box), HBadge.radius);
        expect(
          tester.widget<Text>(find.text('Available')).style!.color,
          mark,
          reason: '$kind ink',
        );
      }
    });
  });
}
