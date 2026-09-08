import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cached_account_read.dart';
import 'package:healthee/data/api/server_snapshot.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notable_event.g.dart';

class NotableEvent {
  factory NotableEvent.fromJson(
    Map<String, Object?> row, {
    required bool validated,
  }) => NotableEvent(
    day: row['date']! as String,
    metric: row['metric']! as String,
    label: row['label']! as String,
    value: (row['value']! as num).toDouble(),
    median: (row['median'] as num?)?.toDouble(),
    meaning: validated ? row['meaning'] as String? ?? '' : '',
    notes: (row['note_ids'] as List<Object?>? ?? []).cast<String>(),
  );
  const NotableEvent({
    required this.day,
    required this.metric,
    required this.label,
    required this.value,
    required this.median,
    required this.meaning,
    required this.notes,
  });
  final String day;
  final String metric;
  final String label;
  final double value;
  final double? median;
  final String meaning;
  final List<String> notes;
}

@riverpod
Stream<ServerSnapshot<List<NotableEvent>>> notableEvents(Ref ref) async* {
  final api = await ref.watch(accountApiProvider.future);
  yield* cachedAccountRead(
    api: api,
    store: ref.watch(localStoreProvider),
    path: '/api/notable',
    key: 'notable_feed',
    parse: (data) => [
      for (final row in data['items']! as List<Object?>)
        NotableEvent.fromJson(
          row! as Map<String, Object?>,
          validated: data['validated'] == true,
        ),
    ],
  );
}
