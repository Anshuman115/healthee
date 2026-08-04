// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [PushClient].

@ProviderFor(pushClient)
final pushClientProvider = PushClientProvider._();

/// The app's [PushClient].

final class PushClientProvider
    extends $FunctionalProvider<PushClient, PushClient, PushClient>
    with $Provider<PushClient> {
  /// The app's [PushClient].
  PushClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushClientHash();

  @$internal
  @override
  $ProviderElement<PushClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushClient create(Ref ref) {
    return pushClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushClient>(value),
    );
  }
}

String _$pushClientHash() => r'25ba321fcd8d33d951636daf281b5dc41d56cee6';
