import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/account_identity.dart';
import 'package:healthee/data/gps/gps_local_store.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gps_repository.g.dart';

class GpsRepository {
  const GpsRepository({required this.local, required this.api});
  final GpsLocalStore local;
  final AccountApi api;

  Future<void> upload(String id) async {
    final recording = await local.recording(id);
    if (recording.status == 'recording') {
      throw const FormatException('Stop the recording before uploading.');
    }
    final points = await local.fixes(id);
    if (points.length < 10) {
      throw const FormatException(
        'At least ten valid GPS fixes are needed to upload.',
      );
    }
    final result = await api.request(
      '/api/workout/gps',
      method: 'POST',
      timeout: Env.pushTimeout,
      body: {
        'client_id': recording.id,
        'start_iso': DateTime.fromMillisecondsSinceEpoch(
          recording.startMs,
          isUtc: true,
        ).toIso8601String(),
        'end_iso': DateTime.fromMillisecondsSinceEpoch(
          recording.endMs!,
          isUtc: true,
        ).toIso8601String(),
        'points': [
          for (final point in points)
            [
              point.atMs / 1000,
              point.latitude,
              point.longitude,
              point.altitudeM,
            ],
        ],
      },
    );
    if (result['ok'] != true || result['track_id'] != recording.id) {
      throw const FormatException(
        'The server did not accept the GPS recording.',
      );
    }
    await local.finish(
      id,
      DateTime.fromMillisecondsSinceEpoch(recording.endMs!),
      status: 'uploaded',
    );
  }
}

@Riverpod(keepAlive: true)
Future<GpsRepository> gpsRepository(Ref ref) async {
  final store = ref.watch(localStoreProvider);
  final identity = await ref.watch(accountIdentityProvider.future);
  final api = await ref.watch(accountApiProvider.future);
  return GpsRepository(
    local: GpsLocalStore(store, identity.storageScope),
    api: api,
  );
}

final localGpsRecordingsProvider =
    StreamProvider.autoDispose<List<GpsRecordingRow>>((ref) async* {
      final repository = await ref.watch(gpsRepositoryProvider.future);
      yield* repository.local.watchRecordings();
    });
