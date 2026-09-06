// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gps_recorder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GpsRecorder)
final gpsRecorderProvider = GpsRecorderProvider._();

final class GpsRecorderProvider
    extends $AsyncNotifierProvider<GpsRecorder, GpsRecordingState> {
  GpsRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gpsRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gpsRecorderHash();

  @$internal
  @override
  GpsRecorder create() => GpsRecorder();
}

String _$gpsRecorderHash() => r'485af14ba65e0d37a9c304fcd64adf17d746dfc0';

abstract class _$GpsRecorder extends $AsyncNotifier<GpsRecordingState> {
  FutureOr<GpsRecordingState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<GpsRecordingState>, GpsRecordingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<GpsRecordingState>, GpsRecordingState>,
              AsyncValue<GpsRecordingState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
