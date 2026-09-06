// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_identity.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountIdentity)
final accountIdentityProvider = AccountIdentityProvider._();

final class AccountIdentityProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountIdentity>,
          AccountIdentity,
          FutureOr<AccountIdentity>
        >
    with $FutureModifier<AccountIdentity>, $FutureProvider<AccountIdentity> {
  AccountIdentityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountIdentityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountIdentityHash();

  @$internal
  @override
  $FutureProviderElement<AccountIdentity> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AccountIdentity> create(Ref ref) {
    return accountIdentity(ref);
  }
}

String _$accountIdentityHash() => r'e4a050d9c6613c97ed6ce52edc7bd237b6f02094';
