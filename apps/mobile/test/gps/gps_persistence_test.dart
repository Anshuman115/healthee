import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/gps/gps_fix.dart';
import 'package:healthee/data/gps/gps_local_store.dart';
import 'package:healthee/data/gps/gps_run.dart';
import 'package:healthee/data/store/local_store.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1);
  late LocalStore store;
  late GpsLocalStore owner;
  setUp(() {
    store = LocalStore.memory();
    owner = GpsLocalStore(store, 'owner-a');
  });
  tearDown(() => store.close());

  test('interrupted recording recovers durable fixes and ownership', () async {
    await owner.begin('route', start);
    await owner.append(
      'route',
      GpsFix(
        at: start.add(const Duration(seconds: 5)),
        latitude: 12,
        longitude: 77,
        accuracyM: 8,
      ),
      15,
    );
    await owner.recoverInterrupted();
    final recovered = await owner.recording('route');
    expect(recovered.status, 'interrupted');
    expect(
      recovered.endMs,
      start.add(const Duration(seconds: 5)).millisecondsSinceEpoch,
    );
    expect(recovered.distanceM, 15);
    expect(await owner.fixes('route'), hasLength(1));
    final other = GpsLocalStore(store, 'owner-b');
    await expectLater(other.recording('route'), throwsFormatException);
    await expectLater(other.fixes('route'), throwsFormatException);
    expect(await other.watchRecordings().first, isEmpty);
  });

  test('recovery leaves acknowledged uploads unchanged', () async {
    await owner.begin('uploaded', start);
    await owner.finish(
      'uploaded',
      start.add(const Duration(minutes: 1)),
      status: 'uploaded',
    );
    await owner.recoverInterrupted();
    expect((await owner.recording('uploaded')).status, 'uploaded');
  });

  test(
    'GPS quality rejects stale, unordered, inaccurate and invalid fixes',
    () {
      GpsFix fix({
        double lat = 12,
        double accuracy = 8,
        DateTime? at,
        double? altitude,
      }) => GpsFix(
        at: at ?? start,
        latitude: lat,
        longitude: 77,
        accuracyM: accuracy,
        altitudeM: altitude,
      );
      expect(GpsRun.validFix(fix(), start, null), isTrue);
      expect(GpsRun.validFix(fix(accuracy: 51), start, null), isFalse);
      expect(GpsRun.validFix(fix(lat: double.nan), start, null), isFalse);
      expect(
        GpsRun.validFix(fix(altitude: double.infinity), start, null),
        isFalse,
      );
      expect(GpsRun.validFix(fix(), start, start), isFalse);
      expect(
        GpsRun.validFix(
          fix(at: start.subtract(const Duration(seconds: 1))),
          start,
          null,
        ),
        isFalse,
      );
    },
  );
}
