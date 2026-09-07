/// The meter's SENTENCE — four shapes on the wire, four things to say.
///
/// Unit tests, not widget tests: `meterLine` is a pure function of an
/// `Entitlement` and an instant, and asking it directly is stronger than reading
/// pixels back off a screen. Split out of `coach_screen_test.dart` at the
/// 400-line gate (Standards section 1); that suite renders the screen, this one
/// asks the function it prints.
///
/// The rule under all of them: **the number is the server's**. Nothing here
/// computes a balance, and nothing manufactures a reset instant the wire did not
/// send — a countdown beside "3 left" would be a clock that is not running.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/entitlement.dart';
import 'package:healthee/features/coach/widgets/coach_meter.dart';

final DateTime _now = DateTime(2026, 8, 5, 9);

/// A subscriber with [remaining] of 20 questions left.
Entitlement _premium({required int remaining, DateTime? resetsAt}) =>
    Entitlement.fromJson(<String, Object?>{
      'premium': true,
      'status': 'active',
      'locked': const <String>[],
      'included': <Object?>[
        <String, Object?>{
          'feature': 'coach',
          'limit': 20,
          'used': 20 - remaining,
          'remaining': remaining,
          'window_days': 30,
          'resets_at': resetsAt?.toIso8601String(),
        },
      ],
      'upgrade': 'https://example.test/upgrade',
    });

void main() {
  group('the meter sentence', () {
    test('never reads as a countdown while a slot is free', () {
      // `resets_at` is null on the wire until the window is full, and the
      // sentence must not manufacture one.
      final line = meterLine(_premium(remaining: 3), now: _now);
      expect(line, contains('3 of 20'));
      expect(line, isNot(contains('reopens')));
    });

    test('a spent window with no reset instant still says it is spent', () {
      final line = meterLine(_premium(remaining: 0), now: _now);
      expect(line, contains('All 20'));
      expect(line, isNot(contains('reopens')));
    });
  });
}
