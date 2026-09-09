/// The card itself: that the distinction `health_lines.dart` draws survives
/// being rendered.
///
/// A pure function that returns the right sentences is worth nothing if the
/// widget prints them all identically, or drops the quiet ones, or reaches for a
/// colour. `README.md` is explicit that colour is a claim about the owner's
/// body, so loud and quiet are typographic here and that is asserted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';

final DateTime _now = DateTime(2026, 8, 4, 9, 30);

Widget _host({PushStamp? push, DateTime? lastStrapSync}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: DataHealthSection(
      push: push,
      lastStrapSync: lastStrapSync,
      signedIn: true,
      now: _now,
    ),
  ),
);

/// The rendered style of the one Text whose content contains [fragment].
TextStyle _styleOf(WidgetTester tester, String fragment) {
  final widget = tester.widget<Text>(find.textContaining(fragment));
  return widget.style!;
}

void main() {
  testWidgets('A MID-DRAIN BACKLOG DOES NOT SAY ANYTHING WENT WRONG', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(push: const PushStamp(pendingRows: 22000, outcomeId: 'paused')),
    );

    expect(find.textContaining("didn't finish"), findsNothing);
    expect(
      find.textContaining('still going out to your server'),
      findsOneWidget,
    );
  });

  testWidgets('and it is drawn quiet — secondary ink, small', (tester) async {
    await tester.pumpWidget(
      _host(push: const PushStamp(pendingRows: 22000, outcomeId: 'paused')),
    );

    final style = _styleOf(tester, 'still going out');
    expect(style.color, const HealtheeColors.light().ink2);
  });

  testWidgets('A TRANSPORT FAILURE DOES SAY SO, in full ink', (tester) async {
    await tester.pumpWidget(
      _host(
        push: const PushStamp(
          pendingRows: 22000,
          outcomeId: 'interrupted',
          failureReason: 'it could not be reached',
        ),
      ),
    );

    expect(find.textContaining("didn't finish"), findsOneWidget);
    expect(
      _styleOf(tester, "didn't finish").color,
      const HealtheeColors.light().ink,
      reason:
          'loud is typography here, not colour — there is one red in this '
          'app and it is for illness',
    );
  });

  testWidgets('a strap gone unread is raised, loudly', (tester) async {
    await tester.pumpWidget(
      _host(lastStrapSync: _now.subtract(const Duration(days: 9))),
    );

    expect(find.textContaining('Your strap was last read'), findsOneWidget);
    expect(
      _styleOf(tester, 'Your strap was last read').color,
      const HealtheeColors.light().ink,
    );
  });

  testWidgets('a healthy phone renders nothing at all', (tester) async {
    await tester.pumpWidget(
      _host(
        push: const PushStamp(pendingRows: 0, outcomeId: 'sent'),
        lastStrapSync: _now.subtract(const Duration(minutes: 4)),
      ),
    );

    expect(find.text('Data health'), findsNothing);
  });
}
