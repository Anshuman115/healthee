import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/data/store/strap_writer.dart';
import 'package:healthee/data/sync/sync_outcome.dart';

import '../ble/_fake_strap.dart';
import 'sync_engine_test.dart' show engineFor;

class BrokenHistoryStrap extends FakeStrap {
  BrokenHistoryStrap()
    : super(
        authKey: parseAuthKey('a1b2c3d4e5f60718293a4b5c6d7e8f90'),
        dailyTotals: (9264, 6710, 412),
        rounds: {
          0x01: [
            Uint8List.fromList([0, 0, 3, 60, 0, 0, 0, 0]),
          ],
        },
      );

  @override
  Future<void> writeActivityControl(List<int> command) async {
    if (command[0] == 1 && command[1] == 0x49) {
      throw const FormatException('radio stopped during HRV fetch');
    }
    await super.writeActivityControl(command);
  }
}

void main() {
  test(
    'a failed stream retains earlier readings without certifying completion',
    () async {
      final wired = engineFor((_) => BrokenHistoryStrap());
      addTearDown(wired.store.close);
      final outcome = await wired.engine.run(
        today: '2026-09-06',
        onState: (_) {},
      );
      expect(outcome, isA<SyncFailed>());
      final window = await wired.store.strapWriter.resumeWindow();
      expect(window.lastSampleAt.containsKey('hr'), isTrue);
      expect(window.lastSampleAt.containsKey('hrv'), isFalse);
      expect(await wired.store.strapWriter.lastCompleteSync(), isNull);
      expect(
        await wired.store.strapWriter.meta(SyncKeys.stressBackfillDone),
        isNull,
      );
      expect(
        await wired.store.strapWriter.meta(SyncKeys.napBackfillDone),
        isNull,
      );
      final pending = await wired.store.pushReader.pending();
      expect(pending.totals.single.steps, 9264);
    },
  );
}
