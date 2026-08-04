// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credentials.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one [Credentials] instance.

@ProviderFor(credentials)
final credentialsProvider = CredentialsProvider._();

/// The app's one [Credentials] instance.

final class CredentialsProvider
    extends $FunctionalProvider<Credentials, Credentials, Credentials>
    with $Provider<Credentials> {
  /// The app's one [Credentials] instance.
  CredentialsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'credentialsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$credentialsHash();

  @$internal
  @override
  $ProviderElement<Credentials> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Credentials create(Ref ref) {
    return credentials(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Credentials value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Credentials>(value),
    );
  }
}

String _$credentialsHash() => r'4bce988f7419e085d1bf9a236ea82c2a88404a42';
