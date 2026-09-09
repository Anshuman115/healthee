// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The whole `/api/activity` response, fetched once.

@ProviderFor(activitySnapshot)
final activitySnapshotProvider = ActivitySnapshotProvider._();

/// The whole `/api/activity` response, fetched once.

final class ActivitySnapshotProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Object?>>,
          Map<String, Object?>,
          FutureOr<Map<String, Object?>>
        >
    with
        $FutureModifier<Map<String, Object?>>,
        $FutureProvider<Map<String, Object?>> {
  /// The whole `/api/activity` response, fetched once.
  ActivitySnapshotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activitySnapshotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activitySnapshotHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Object?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Object?>> create(Ref ref) {
    return activitySnapshot(ref);
  }
}

String _$activitySnapshotHash() => r'c5229b6c8e19331ec9c8d7802c57ae275c74812e';

@ProviderFor(workoutHistory)
final workoutHistoryProvider = WorkoutHistoryProvider._();

final class WorkoutHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutSummary>>,
          List<WorkoutSummary>,
          FutureOr<List<WorkoutSummary>>
        >
    with
        $FutureModifier<List<WorkoutSummary>>,
        $FutureProvider<List<WorkoutSummary>> {
  WorkoutHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutHistoryHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkoutSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkoutSummary>> create(Ref ref) {
    return workoutHistory(ref);
  }
}

String _$workoutHistoryHash() => r'e29cfe75520e39dec248b561152ca8982b824794';

/// The VO₂max plan, or null when the server sent no block for it.

@ProviderFor(fitnessPlan)
final fitnessPlanProvider = FitnessPlanProvider._();

/// The VO₂max plan, or null when the server sent no block for it.

final class FitnessPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<FitnessPlan?>,
          FitnessPlan?,
          FutureOr<FitnessPlan?>
        >
    with $FutureModifier<FitnessPlan?>, $FutureProvider<FitnessPlan?> {
  /// The VO₂max plan, or null when the server sent no block for it.
  FitnessPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fitnessPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fitnessPlanHash();

  @$internal
  @override
  $FutureProviderElement<FitnessPlan?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FitnessPlan?> create(Ref ref) {
    return fitnessPlan(ref);
  }
}

String _$fitnessPlanHash() => r'bcb76a3f8ae52f78400d2911acca89fdddb260f7';

@ProviderFor(workoutDetail)
final workoutDetailProvider = WorkoutDetailFamily._();

final class WorkoutDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutDetail>,
          WorkoutDetail,
          FutureOr<WorkoutDetail>
        >
    with $FutureModifier<WorkoutDetail>, $FutureProvider<WorkoutDetail> {
  WorkoutDetailProvider._({
    required WorkoutDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutDetailHash();

  @override
  String toString() {
    return r'workoutDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WorkoutDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkoutDetail> create(Ref ref) {
    final argument = this.argument as String;
    return workoutDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutDetailHash() => r'505f26752f1dfe8631c764c126d6a061630e58cd';

final class WorkoutDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WorkoutDetail>, String> {
  WorkoutDetailFamily._()
    : super(
        retry: null,
        name: r'workoutDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkoutDetailProvider call(String start) =>
      WorkoutDetailProvider._(argument: start, from: this);

  @override
  String toString() => r'workoutDetailProvider';
}
