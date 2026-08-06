/// What the data-health card says, and — more importantly — what it does not.
///
/// The rule under test is that a deliberate stop and a fault read differently to
/// the owner. Before the split they did not: a push that hit its own page cap
/// and was about to continue printed "The last attempt to send your data didn't
/// finish", which is this product's honesty contract pointed at itself and
/// getting it wrong.
///
/// The strap-horizon warning is tested at its exact boundary. It fires after a
/// number of DAYS, so an off-by-one in it is a bug nobody notices until the week
/// it costs somebody their data.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/sync/health_lines.dart';

final DateTime _now = DateTime(2026, 8, 4, 9, 30);

/// Every sentence, joined — for assertions about what is absent.
String _joined(List<HealthLine> lines) => lines.map((l) => l.text).join('\n');

/// A stamp for a push that stopped at its own page cap. Not a fault.
PushStamp _paused({int rows = 22000}) => PushStamp(
  pendingRows: rows,
  outcomeId: 'paused',
  lastAttempt: _now,
);

/// A stamp for a push whose transport died. A fault.
PushStamp _interrupted({int rows = 22000}) => PushStamp(
  pendingRows: rows,
  outcomeId: 'interrupted',
  failureReason: 'it could not be reached',
  lastAttempt: _now,
);

void main() {
  test('nothing wrong says nothing at all', () {
    expect(dataHealthLines(now: _now, push: const PushStamp.never()), isEmpty);
    expect(dataHealthLines(now: _now), isEmpty);
  });

  group('a cap-partial', () {
    test('DOES NOT RENDER AS A FAULT', () {
      final lines = dataHealthLines(now: _now, push: _paused());

      expect(
        _joined(lines),
        isNot(contains("didn't finish")),
        reason: 'the design working is not a failure, and saying it is teaches '
            'the owner to ignore the one card that must be believed',
      );
      expect(lines.every((line) => !line.loud), isTrue);
    });

    test('and shows quiet progress instead', () {
      final lines = dataHealthLines(now: _now, push: _paused());

      expect(_joined(lines), contains('22000 measurements are still going out'));
      expect(lines, hasLength(1));
    });
  });

  group('a transport-failure partial', () {
    test('DOES RENDER AS A FAULT', () {
      final lines = dataHealthLines(now: _now, push: _interrupted());

      expect(_joined(lines), contains("didn't finish"));
      expect(_joined(lines), contains('it could not be reached'));
      expect(lines.first.loud, isTrue);
    });

    test('and does NOT promise the next sync will fix it', () {
      final lines = dataHealthLines(now: _now, push: _interrupted());

      expect(
        _joined(lines),
        isNot(contains('go out on the next sync')),
        reason: 'the next sync fails the same way; a promise nothing can keep '
            'is the flattery this product exists against',
      );
      // What IS true is said plainly, and only that.
      expect(_joined(lines), contains('Nothing is marked sent'));
      expect(_joined(lines), contains('will not reach the server'));
    });

    test('the fault comes before the backlog line that refers to it', () {
      final lines = dataHealthLines(now: _now, push: _interrupted());

      expect(lines.first.text, contains("didn't finish"));
      expect(lines[1].text, contains('the problem above'));
    });
  });

  group('a backlog with no push behind it yet', () {
    test('is quiet, and "nothing is lost" is true there', () {
      // Rows arrived after the last good push. Self-healing, and the queue is
      // durable — nothing is marked sent until the server has it.
      final lines = dataHealthLines(
        now: _now,
        push: const PushStamp(pendingRows: 40, outcomeId: 'sent'),
      );

      expect(_joined(lines), contains('Nothing is lost'));
      expect(lines.single.loud, isFalse);
    });

    test('a signed-out phone is LOUD, because only the owner can clear it', () {
      final lines = dataHealthLines(
        now: _now,
        push: const PushStamp(pendingRows: 40, outcomeId: 'skipped'),
      );

      expect(lines.single.loud, isTrue);
      expect(_joined(lines), contains('until this phone is signed in'));
    });
  });

  group('the strap horizon — the ONE thing here that can lose data', () {
    List<HealthLine> after(Duration gap) =>
        dataHealthLines(now: _now, lastStrapSync: _now.subtract(gap));

    test('a strap read this morning says nothing', () {
      expect(after(const Duration(hours: 3)), isEmpty);
    });

    test('AT EXACTLY THE THRESHOLD it is still silent', () {
      expect(
        after(kStrapHorizonWarning),
        isEmpty,
        reason: 'the boundary has one meaning, pinned so a later `>=` fails here',
      );
    });

    test('ONE SECOND PAST IT, IT SPEAKS', () {
      final lines = after(kStrapHorizonWarning + const Duration(seconds: 1));

      expect(lines, hasLength(1));
      expect(lines.single.loud, isTrue, reason: 'the owner must actually act');
      expect(lines.single.text, contains('Your strap was last read'));
    });

    test('it says what to do, and the doing is opening the app', () {
      final lines = after(const Duration(days: 8));

      expect(_joined(lines), contains('Open this app near your strap'));
      expect(_joined(lines), contains('8 d ago'));
    });

    test('IT NAMES NO DATE, because we do not know one', () {
      // The retention is inferred from a single observed backfill, not measured.
      // "You will lose data on Thursday" would be a precise claim on one data
      // point — the shape of dishonesty this product is built against.
      final text = _joined(after(const Duration(days: 8)));

      expect(text, contains('about a week or two'));
      expect(text, contains('may'));
      expect(text, isNot(contains('will be lost')));
      expect(text, isNot(contains('2026-')));
    });

    test('a phone that has NEVER synced is left to the connection strip', () {
      // "Never synced — tap Sync now" is already on screen, in the chrome. Two
      // voices on one fact is how a card stops being read.
      expect(dataHealthLines(now: _now), isEmpty);
    });

    test('it outranks a quiet push line', () {
      final lines = dataHealthLines(
        now: _now,
        push: _paused(),
        lastStrapSync: _now.subtract(const Duration(days: 8)),
      );

      expect(lines.first.text, contains('Your strap was last read'));
      expect(lines.last.text, contains('still going out'));
    });
  });

  test('the cached-snapshot line is provenance, not a fault', () {
    final lines = dataHealthLines(
      now: _now,
      cachedAt: _now.subtract(const Duration(hours: 2)),
    );

    expect(lines.single.loud, isFalse);
    expect(lines.single.text, contains('last snapshot the server sent'));
    expect(lines.single.text, contains('2 h ago'));
  });
}
