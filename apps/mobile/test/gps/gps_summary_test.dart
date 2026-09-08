import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';

void main() {
  test('elapsed pace includes stops and freezes at recording end', () {
    final start = DateTime.utc(2026, 1, 1);
    final end = start.add(const Duration(minutes: 30));
    final state = GpsRecordingState(start: start, end: end, distanceM: 5000);
    expect(state.elapsedAt(end.add(const Duration(hours: 2))).inMinutes, 30);
    expect(state.paceAt(end), 6);
    expect(GpsRecordingState(start: start).paceAt(end), isNull);
  });
}
