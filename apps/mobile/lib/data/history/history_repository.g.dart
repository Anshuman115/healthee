// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Bounded, account-bound daily observations. Missing days are never padded.

@ProviderFor(metricHistory)
final metricHistoryProvider = MetricHistoryFamily._();

/// Bounded, account-bound daily observations. Missing days are never padded.

final class MetricHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrendPoint>>,
          List<TrendPoint>,
          FutureOr<List<TrendPoint>>
        >
    with $FutureModifier<List<TrendPoint>>, $FutureProvider<List<TrendPoint>> {
  /// Bounded, account-bound daily observations. Missing days are never padded.
  MetricHistoryProvider._({
    required MetricHistoryFamily super.from,
    required (HistoryMetric, int) super.argument,
  }) : super(
         retry: null,
         name: r'metricHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metricHistoryHash();

  @override
  String toString() {
    return r'metricHistoryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<TrendPoint>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TrendPoint>> create(Ref ref) {
    final argument = this.argument as (HistoryMetric, int);
    return metricHistory(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MetricHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metricHistoryHash() => r'0e9bfeeaf15444c62912d81c22ab132f9560679d';

/// Bounded, account-bound daily observations. Missing days are never padded.

final class MetricHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<TrendPoint>>,
          (HistoryMetric, int)
        > {
  MetricHistoryFamily._()
    : super(
        retry: null,
        name: r'metricHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Bounded, account-bound daily observations. Missing days are never padded.

  MetricHistoryProvider call(HistoryMetric metric, int days) =>
      MetricHistoryProvider._(argument: (metric, days), from: this);

  @override
  String toString() => r'metricHistoryProvider';
}
