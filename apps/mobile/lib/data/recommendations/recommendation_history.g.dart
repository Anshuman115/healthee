// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_history.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recommendationHistory)
final recommendationHistoryProvider = RecommendationHistoryFamily._();

final class RecommendationHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DatedRecommendation>>,
          List<DatedRecommendation>,
          FutureOr<List<DatedRecommendation>>
        >
    with
        $FutureModifier<List<DatedRecommendation>>,
        $FutureProvider<List<DatedRecommendation>> {
  RecommendationHistoryProvider._({
    required RecommendationHistoryFamily super.from,
    required (int, int) super.argument,
  }) : super(
         retry: null,
         name: r'recommendationHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recommendationHistoryHash();

  @override
  String toString() {
    return r'recommendationHistoryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<DatedRecommendation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DatedRecommendation>> create(Ref ref) {
    final argument = this.argument as (int, int);
    return recommendationHistory(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RecommendationHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recommendationHistoryHash() =>
    r'2feb4269df6b1a1f38a1aa8583692df289afe52f';

final class RecommendationHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<DatedRecommendation>>,
          (int, int)
        > {
  RecommendationHistoryFamily._()
    : super(
        retry: null,
        name: r'recommendationHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecommendationHistoryProvider call(int days, int page) =>
      RecommendationHistoryProvider._(argument: (days, page), from: this);

  @override
  String toString() => r'recommendationHistoryProvider';
}
