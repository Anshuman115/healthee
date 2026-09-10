// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credentials.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one [Credentials] instance.
/// The app's ONE keystore handle.
///
/// Its own provider because two things now write owner secrets — [Credentials]
/// for the strap, the server session and the Zepp account, and
/// `data/auth/identity_store.dart` for the Supabase session that `gotrue` owns.
/// Two `FlutterSecureStorage` instances with different options is two different
/// keychains on iOS, and a value written under one is simply absent under the
/// other. One handle, one set of options, one place to change them.

@ProviderFor(secretStore)
final secretStoreProvider = SecretStoreProvider._();

/// The app's one [Credentials] instance.
/// The app's ONE keystore handle.
///
/// Its own provider because two things now write owner secrets — [Credentials]
/// for the strap, the server session and the Zepp account, and
/// `data/auth/identity_store.dart` for the Supabase session that `gotrue` owns.
/// Two `FlutterSecureStorage` instances with different options is two different
/// keychains on iOS, and a value written under one is simply absent under the
/// other. One handle, one set of options, one place to change them.

final class SecretStoreProvider
    extends $FunctionalProvider<SecretStore, SecretStore, SecretStore>
    with $Provider<SecretStore> {
  /// The app's one [Credentials] instance.
  /// The app's ONE keystore handle.
  ///
  /// Its own provider because two things now write owner secrets — [Credentials]
  /// for the strap, the server session and the Zepp account, and
  /// `data/auth/identity_store.dart` for the Supabase session that `gotrue` owns.
  /// Two `FlutterSecureStorage` instances with different options is two different
  /// keychains on iOS, and a value written under one is simply absent under the
  /// other. One handle, one set of options, one place to change them.
  SecretStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secretStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secretStoreHash();

  @$internal
  @override
  $ProviderElement<SecretStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecretStore create(Ref ref) {
    return secretStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecretStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecretStore>(value),
    );
  }
}

String _$secretStoreHash() => r'df8bca5e032df291b53e9c9d96af4c278d1a9505';

/// The app's [Credentials], over the shared keystore.

@ProviderFor(credentials)
final credentialsProvider = CredentialsProvider._();

/// The app's [Credentials], over the shared keystore.

final class CredentialsProvider
    extends $FunctionalProvider<Credentials, Credentials, Credentials>
    with $Provider<Credentials> {
  /// The app's [Credentials], over the shared keystore.
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

String _$credentialsHash() => r'3732063fb44204c773aa6ac1742ccc9f4d3f0b1e';
