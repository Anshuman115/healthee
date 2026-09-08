// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recordedRoutes)
final recordedRoutesProvider = RecordedRoutesProvider._();

final class RecordedRoutesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RouteSummary>>,
          List<RouteSummary>,
          FutureOr<List<RouteSummary>>
        >
    with
        $FutureModifier<List<RouteSummary>>,
        $FutureProvider<List<RouteSummary>> {
  RecordedRoutesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordedRoutesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordedRoutesHash();

  @$internal
  @override
  $FutureProviderElement<List<RouteSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RouteSummary>> create(Ref ref) {
    return recordedRoutes(ref);
  }
}

String _$recordedRoutesHash() => r'8aaf2fb67b8270335430371ba51fd91c9ed81bd0';

@ProviderFor(recordedRoute)
final recordedRouteProvider = RecordedRouteFamily._();

final class RecordedRouteProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecordedRoute>,
          RecordedRoute,
          FutureOr<RecordedRoute>
        >
    with $FutureModifier<RecordedRoute>, $FutureProvider<RecordedRoute> {
  RecordedRouteProvider._({
    required RecordedRouteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordedRouteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordedRouteHash();

  @override
  String toString() {
    return r'recordedRouteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RecordedRoute> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RecordedRoute> create(Ref ref) {
    final argument = this.argument as String;
    return recordedRoute(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordedRouteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordedRouteHash() => r'45d508ad9612d3b6e5762665abb9a493d554ae0e';

final class RecordedRouteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RecordedRoute>, String> {
  RecordedRouteFamily._()
    : super(
        retry: null,
        name: r'recordedRouteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecordedRouteProvider call(String id) =>
      RecordedRouteProvider._(argument: id, from: this);

  @override
  String toString() => r'recordedRouteProvider';
}
