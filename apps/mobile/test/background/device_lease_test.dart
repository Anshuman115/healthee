import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/device_lease.dart';

void main() {
  test(
    'two database connections cannot own the strap together; expired owner cannot release successor',
    () async {
      final directory = await Directory.systemTemp.createTemp('healthee-lease');
      final a = LocalStore.at('${directory.path}/store.sqlite');
      final b = LocalStore.at('${directory.path}/store.sqlite');
      var now = DateTime.utc(2026, 1, 1);
      final first = DeviceLease(a, now: () => now);
      final second = DeviceLease(b, now: () => now);
      final third = DeviceLease(a, now: () => now);
      addTearDown(() async {
        await first.release();
        await second.release();
        await third.release();
        await a.close();
        await b.close();
        await directory.delete(recursive: true);
      });
      expect(await first.acquire(), isTrue);
      expect(await second.acquire(), isFalse);
      now = now.add(DeviceLease.expiry + const Duration(seconds: 1));
      expect(await second.acquire(), isTrue);
      await first.release();
      expect(await third.acquire(), isFalse);
      await second.release();
      expect(await third.acquire(), isTrue);
    },
  );
}
