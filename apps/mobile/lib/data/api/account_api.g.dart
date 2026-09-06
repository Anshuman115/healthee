// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountApi)
final accountApiProvider = AccountApiProvider._();

final class AccountApiProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountApi>,
          AccountApi,
          FutureOr<AccountApi>
        >
    with $FutureModifier<AccountApi>, $FutureProvider<AccountApi> {
  AccountApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountApiHash();

  @$internal
  @override
  $FutureProviderElement<AccountApi> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AccountApi> create(Ref ref) {
    return accountApi(ref);
  }
}

String _$accountApiHash() => r'c4bf3b537b8fa91c730c175d6d240844aec5dd33';
