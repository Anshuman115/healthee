// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_marker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(historyMarkers)
final historyMarkersProvider = HistoryMarkersFamily._();

final class HistoryMarkersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HistoryMarker>>,
          List<HistoryMarker>,
          FutureOr<List<HistoryMarker>>
        >
    with
        $FutureModifier<List<HistoryMarker>>,
        $FutureProvider<List<HistoryMarker>> {
  HistoryMarkersProvider._({
    required HistoryMarkersFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'historyMarkersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$historyMarkersHash();

  @override
  String toString() {
    return r'historyMarkersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<HistoryMarker>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HistoryMarker>> create(Ref ref) {
    final argument = this.argument as int;
    return historyMarkers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HistoryMarkersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$historyMarkersHash() => r'3506c6d38584ab1ee91fac3b94640512b52b4262';

final class HistoryMarkersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<HistoryMarker>>, int> {
  HistoryMarkersFamily._()
    : super(
        retry: null,
        name: r'historyMarkersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HistoryMarkersProvider call(int days) =>
      HistoryMarkersProvider._(argument: days, from: this);

  @override
  String toString() => r'historyMarkersProvider';
}
