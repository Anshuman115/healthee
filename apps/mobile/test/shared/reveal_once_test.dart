/// Charts animate once and never again — the known, expensive legacy bug.
///
/// The test that carries the rule is the second one. `ListView.builder` destroys
/// an item's element on scroll-off and builds a **fresh widget and a fresh
/// State** on scroll-back, so an animation held in the chart itself replays
/// every time. Here that is reproduced literally: a second `RevealOnce` is built
/// with the same id against the same registry, exactly as the list would, and it
/// must start finished rather than at zero.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Records every progress value its builder is called with.
Widget _probe(RevealRegistry registry, List<double> seen, {Object id = 'chart'}) {
  return MaterialApp(
    home: RevealOnce(
      id: id,
      registry: registry,
      duration: const Duration(milliseconds: 200),
      builder: (context, t) {
        seen.add(t);
        return const SizedBox(width: 10, height: 10);
      },
    ),
  );
}

void main() {
  testWidgets('the first reveal animates from nothing to whole', (tester) async {
    final registry = RevealRegistry();
    final seen = <double>[];

    await tester.pumpWidget(_probe(registry, seen));
    expect(seen.first, 0);

    await tester.pumpAndSettle();
    expect(seen.last, 1);
    expect(seen.length, greaterThan(2), reason: 'it genuinely animated');
  });

  testWidgets('A REBUILT ITEM DOES NOT ANIMATE AGAIN', (tester) async {
    final registry = RevealRegistry();
    await tester.pumpWidget(_probe(registry, <double>[]));
    await tester.pumpAndSettle();

    // The scroll-back: a brand new widget and State for the same chart.
    final second = <double>[];
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(_probe(registry, second));

    expect(
      second,
      everyElement(1.0),
      reason: 'a chart that replays on scroll-back is the legacy bug',
    );
  });

  testWidgets('two charts have independent reveals', (tester) async {
    final registry = RevealRegistry();
    await tester.pumpWidget(_probe(registry, <double>[]));
    await tester.pumpAndSettle();

    final other = <double>[];
    // The empty frame forces a new element, exactly as scrolling the first
    // chart out of view would — without it Flutter reuses the State and the
    // test would be measuring widget identity rather than the registry.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(_probe(registry, other, id: 'second-chart'));

    expect(
      other.first,
      0,
      reason: "seeing one chart must not silently skip another chart's reveal",
    );
  });

  test('reset lets new data earn a fresh reveal', () {
    final registry = RevealRegistry();

    expect(registry.markSeen('chart'), isTrue);
    expect(registry.markSeen('chart'), isFalse);
    registry.reset();
    expect(
      registry.markSeen('chart'),
      isTrue,
      reason: 'pull-to-refresh may reset; scrolling never does',
    );
  });
}
