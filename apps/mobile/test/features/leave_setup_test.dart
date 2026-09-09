/// `leaveSetup` — the one door that has two ways in, and so two ways out.
///
/// Split out of `out_of_shell_navigation_test.dart` at the 400-line gate
/// (Standards section 1) when the `parents` back-map joined that suite. The seam
/// is the subject: that file drives the app's REAL router and the screens the
/// avatar opens; this one drives a two-route toy router, because what is under
/// test is a decision `leaveSetup` makes from `canPop()` alone.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/app_theme.dart';

void main() {
  group('leaving a setup flow the way you came into it', () {
    /// A router whose setup screen is either pushed onto a home or IS the
    /// initial location — the two ways `/pairing` is actually reached.
    Widget host({required bool pushed, required List<String> landed}) {
      final router = GoRouter(
        initialLocation: pushed ? '/home' : '/setup',
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(context.push('/setup')),
                child: const Text('open setup'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.today,
            builder: (context, state) {
              landed.add(Routes.today);
              return const Scaffold(body: Text('today'));
            },
          ),
          GoRoute(
            path: '/setup',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => leaveSetup(context),
                child: const Text('done'),
              ),
            ),
          ),
        ],
      );
      return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
    }

    testWidgets('PUSHED: done pops back to what opened it', (tester) async {
      final landed = <String>[];
      await tester.pumpWidget(host(pushed: true, landed: landed));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open setup'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();

      expect(find.text('open setup'), findsOneWidget);
      expect(
        landed,
        isEmpty,
        reason: 'Today is not where this owner came from',
      );
    });

    testWidgets(
      'REDIRECTED INTO: done goes to Today, because nothing is under it',
      (tester) async {
        final landed = <String>[];
        await tester.pumpWidget(host(pushed: false, landed: landed));
        await tester.pumpAndSettle();

        await tester.tap(find.text('done'));
        await tester.pumpAndSettle();

        expect(find.text('today'), findsOneWidget);
        expect(landed, <String>[Routes.today]);
      },
    );
  });
}
