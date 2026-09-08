// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dated_history.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every dated series, in one request. See the library docstring.

@ProviderFor(datedHistory)
final datedHistoryProvider = DatedHistoryProvider._();

/// Every dated series, in one request. See the library docstring.

final class DatedHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<DatedHistory>,
          DatedHistory,
          FutureOr<DatedHistory>
        >
    with $FutureModifier<DatedHistory>, $FutureProvider<DatedHistory> {
  /// Every dated series, in one request. See the library docstring.
  DatedHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'datedHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$datedHistoryHash();

  @$internal
  @override
  $FutureProviderElement<DatedHistory> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DatedHistory> create(Ref ref) {
    return datedHistory(ref);
  }
}

String _$datedHistoryHash() => r'98d650ebce4fdb677bff683c734312d81f57bb08';
