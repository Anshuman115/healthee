import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/gps/recorded_route.dart';
import 'package:healthee/data/gps/route_summary.dart';
import 'package:healthee/data/insights/notable_event.dart';

import 'commitment_contract_test.dart' show snapshot;

void main() {
  test('GPS list and detail parse the same server track', () {
    final list = snapshot('gps_list')['tracks']! as List<Object?>;
    final summary = RouteSummary.fromJson(list.first! as Map<String, Object?>);
    final detail = RecordedRoute.fromJson(snapshot('gps_detail'));
    expect(summary.id, detail.id);
    expect(detail.points, isNotEmpty);
    expect(detail.distanceKm, isNotNull);
    expect(detail.maxHr, 69);
    expect(detail.elevationMinM, 895);
    expect(detail.elevationMaxM, 899);
    expect(detail.points.first.latitude.abs(), lessThanOrEqualTo(90));
  });
  test(
    'unvalidated notable interpretation is withheld while observations remain',
    () {
      final event = NotableEvent.fromJson({
        'date': '2026-09-01',
        'metric': 'rhr_daily',
        'label': 'Resting HR',
        'value': 61,
        'median': 55,
        'meaning': 'Unvalidated advice',
        'note_ids': <String>[],
      }, validated: false);
      expect(event.meaning, isEmpty);
      expect(event.value, 61);
      expect(event.median, 55);
    },
  );
}
