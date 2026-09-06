import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/gps/gps_fix.dart';
import 'package:healthee/data/gps/gps_local_store.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';
import 'package:healthee/data/gps/gps_run.dart';
import 'package:healthee/data/gps/location_source.dart';
import 'package:healthee/data/store/local_store.dart';

void main() {
  late LocalStore store;
  late GpsLocalStore local;
  late ScriptedLocation source;
  final start = DateTime.utc(2026, 1, 1);
  setUp(() async {
    store = LocalStore.memory();
    local = GpsLocalStore(store, 'owner');
    source = ScriptedLocation();
    await local.begin('run', start);
  });
  tearDown(() async { await source.controller.close(); await store.close(); });
  GpsFix fix(int second) => GpsFix(at: start.add(Duration(seconds: second)),
    latitude: 12 + second / 10000, longitude: 77, accuracyM: 8);

  test('Stop drains queued points before returning, rejects duplicates, is idempotent', () async {
    final updates = <GpsRecordingState>[];
    final run = GpsRun(local: local, source: source, onChanged: updates.add,
      id: 'run', start: start)..listen();
    for (var i = 1; i <= 12; i++) { source.controller.add(fix(i)); }
    source.controller.add(fix(12));
    await run.stop();
    expect(await local.fixes('run'), hasLength(12));
    expect((await local.recording('run')).status, 'ready');
    expect(updates.last.recording, isFalse);
    expect(updates.last.points, 12);
    await run.stop();
    expect(await local.fixes('run'), hasLength(12));
  });
  test('location error finalizes saved points and surfaces interruption', () async {
    final stopped = Completer<GpsRecordingState>();
    GpsRun(local: local, source: source,
      onChanged: (value) { if (!value.recording) stopped.complete(value); },
      id: 'run', start: start).listen();
    source.controller.add(fix(1));
    source.controller.addError(const FormatException('Location disconnected'));
    final result = await stopped.future;
    expect(result.error, 'Location disconnected');
    expect(result.points, 1);
    expect((await local.recording('run')).status, 'interrupted');
    expect(await local.fixes('run'), hasLength(1));
  });
}

class ScriptedLocation extends LocationSource {
  final controller = StreamController<GpsFix>(sync: true);
  @override
  Stream<GpsFix> fixes() => controller.stream;
}
