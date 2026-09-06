// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileRepository>,
          ProfileRepository,
          FutureOr<ProfileRepository>
        >
    with
        $FutureModifier<ProfileRepository>,
        $FutureProvider<ProfileRepository> {
  ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<ProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileRepository> create(Ref ref) {
    return profileRepository(ref);
  }
}

String _$profileRepositoryHash() => r'a6762f1e86b275d2d17958685da5c718df21632c';

@ProviderFor(healthProfile)
final healthProfileProvider = HealthProfileProvider._();

final class HealthProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<HealthProfile>,
          HealthProfile,
          FutureOr<HealthProfile>
        >
    with $FutureModifier<HealthProfile>, $FutureProvider<HealthProfile> {
  HealthProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthProfileHash();

  @$internal
  @override
  $FutureProviderElement<HealthProfile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HealthProfile> create(Ref ref) {
    return healthProfile(ref);
  }
}

String _$healthProfileHash() => r'7e49484257e2e72baa29091049e99eddd27b0022';
