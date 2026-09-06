import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';

void main() {
  test(
    'v3 upgrade discards unowned cache but preserves pending strap data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'healthee-cache-upgrade-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/store.sqlite';
      final old = LocalStore.at(path);
      await old.customStatement(
        'INSERT INTO strap_samples '
        '(metric, ts_ms, day, value) VALUES (?, ?, ?, ?)',
        ['hr', 1788652800000, '2026-09-06', 60],
      );
      await old.customStatement('DROP TABLE cached_payloads');
      await old.customStatement(
        'CREATE TABLE cached_payloads ('
        'day TEXT NOT NULL, metric TEXT NOT NULL, payload TEXT NOT NULL, '
        'fetched_at TEXT NOT NULL, PRIMARY KEY(day, metric))',
      );
      await old.customStatement(
        'INSERT INTO cached_payloads VALUES (?, ?, ?, ?)',
        [
          '2026-09-06',
          'today',
          '{"date":"2026-09-06"}',
          '2026-09-06T00:00:00Z',
        ],
      );
      await old.customStatement('DROP TABLE gps_fixes');
      await old.customStatement('DROP TABLE gps_recordings');
      await old.customStatement('PRAGMA user_version = 3');
      await old.close();

      final upgraded = LocalStore.at(path);
      addTearDown(upgraded.close);
      expect(await upgraded.readLatest('today'), isNull);
      expect(await upgraded.pushReader.pendingCount(), 1);
      final sample = (await upgraded.pushReader.pending()).samples.single;
      expect(sample.value, 60);
      expect(sample.pushedAtMs, isNull);
    },
  );
}
