import 'dart:async';

import 'package:healthee/core/logging.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';
import 'package:healthee/data/gps/gps_repository.dart';
import 'package:healthee/data/gps/gps_run.dart';
import 'package:healthee/data/gps/location_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'gps_recorder.g.dart';

@Riverpod(keepAlive: true)
class GpsRecorder extends _$GpsRecorder {
  GpsRun? _run;
  int _generation = 0;
  late GpsRepository _repository;
  late LocationSource _source;

  @override
  Future<GpsRecordingState> build() async {
    final generation = ++_generation;
    final previousRun = _run;
    _run = null;
    _source = ref.watch(locationSourceProvider);
    ref.onDispose(() {
      if (generation == _generation) {
        ++_generation;
        final run = _run;
        if (run != null) unawaited(_close(run));
      }
    });
    if (previousRun != null) await _close(previousRun);
    final repository = await ref.watch(gpsRepositoryProvider.future);
    if (!ref.mounted || generation != _generation) {
      return const GpsRecordingState();
    }
    _repository = repository;
    await repository.local.recoverInterrupted();
    return const GpsRecordingState();
  }

  Future<void> start() async {
    if (state.isLoading ||
        state.hasError ||
        state.value?.recording == true ||
        state.value?.busy == true) {
      return;
    }
    final generation = _generation;
    final repository = _repository;
    final source = _source;
    state = const AsyncData(GpsRecordingState(busy: true));
    try {
      await source.authorize();
      await repository.api.ensureCurrent();
      if (!ref.mounted || generation != _generation) return;
      final id = const Uuid().v4();
      final start = DateTime.now().toUtc();
      await repository.local.recoverInterrupted();
      await repository.local.begin(id, start);
      if (!ref.mounted || generation != _generation) return;
      final run = GpsRun(
        local: repository.local,
        source: source,
        id: id,
        start: start,
        onChanged: (value) {
          if (ref.mounted && generation == _generation) {
            state = AsyncData(value);
          }
        },
      );
      _run = run;
      state = AsyncData(run.value);
      run.listen();
    } on Exception catch (error, stack) {
      AppLog.failure('gps', 'starting route', error, stack);
      final run = _run;
      if (run != null && generation == _generation) await _close(run);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          GpsRecordingState(
            error: error is FormatException
                ? error.message
                : 'Could not start GPS. Check location permission and try again.',
          ),
        );
      }
    }
  }

  Future<void> stopAndUpload() async {
    final repository = _repository;
    final run = _run;
    if (run == null) return;
    await run.stop();
    await repository.upload(run.value.id!);
  }

  Future<void> stop() async {
    await _run?.stop();
  }

  Future<void> _close(GpsRun run) async {
    try {
      await run.stop(interrupted: true);
    } on Exception catch (error, stack) {
      AppLog.failure('gps', 'closing route after session change', error, stack);
    }
  }
}
