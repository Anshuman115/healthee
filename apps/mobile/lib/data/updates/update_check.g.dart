// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_check.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether a newer build is published. Never throws; unknown is an answer.

@ProviderFor(updateStatus)
final updateStatusProvider = UpdateStatusProvider._();

/// Whether a newer build is published. Never throws; unknown is an answer.

final class UpdateStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<UpdateStatus>,
          UpdateStatus,
          FutureOr<UpdateStatus>
        >
    with $FutureModifier<UpdateStatus>, $FutureProvider<UpdateStatus> {
  /// Whether a newer build is published. Never throws; unknown is an answer.
  UpdateStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateStatusHash();

  @$internal
  @override
  $FutureProviderElement<UpdateStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UpdateStatus> create(Ref ref) {
    return updateStatus(ref);
  }
}

String _$updateStatusHash() => r'e92fcfa1c5416c793e8db55b48d383cf3b4dcc5a';
