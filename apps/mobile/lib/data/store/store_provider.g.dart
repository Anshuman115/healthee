// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's local database.

@ProviderFor(localStore)
final localStoreProvider = LocalStoreProvider._();

/// The app's local database.

final class LocalStoreProvider
    extends $FunctionalProvider<LocalStore, LocalStore, LocalStore>
    with $Provider<LocalStore> {
  /// The app's local database.
  LocalStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localStoreHash();

  @$internal
  @override
  $ProviderElement<LocalStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalStore create(Ref ref) {
    return localStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalStore>(value),
    );
  }
}

String _$localStoreHash() => r'cfc19ab85e864c81c0417c9bcd0e205c7aff266e';

/// The owner-local calendar date the app is showing, `YYYY-MM-DD`.
///
/// A provider rather than a `DateTime.now()` call inside the screen, for two
/// reasons that are really one: a test must be able to pin the day (a suite that
/// depends on the wall clock fails at midnight and passes on the retry), and
/// there must be exactly one answer to "what day is it" on a screen that files
/// nine things under it. Standards §3 bans string-literal user constants for the
/// same reason — a value the app reasons about belongs somewhere it can be
/// overridden.
///
/// **Local, deliberately.** The strap counts steps to ITS local midnight and the
/// store files rows by local calendar date, so the day the owner is living in is
/// the only one that lines up. `DateTime.now().toUtc()` here would show an
/// Asia/Kolkata owner yesterday's steps for the first five and a half hours of
/// every day.

@ProviderFor(today)
final todayProvider = TodayProvider._();

/// The owner-local calendar date the app is showing, `YYYY-MM-DD`.
///
/// A provider rather than a `DateTime.now()` call inside the screen, for two
/// reasons that are really one: a test must be able to pin the day (a suite that
/// depends on the wall clock fails at midnight and passes on the retry), and
/// there must be exactly one answer to "what day is it" on a screen that files
/// nine things under it. Standards §3 bans string-literal user constants for the
/// same reason — a value the app reasons about belongs somewhere it can be
/// overridden.
///
/// **Local, deliberately.** The strap counts steps to ITS local midnight and the
/// store files rows by local calendar date, so the day the owner is living in is
/// the only one that lines up. `DateTime.now().toUtc()` here would show an
/// Asia/Kolkata owner yesterday's steps for the first five and a half hours of
/// every day.

final class TodayProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The owner-local calendar date the app is showing, `YYYY-MM-DD`.
  ///
  /// A provider rather than a `DateTime.now()` call inside the screen, for two
  /// reasons that are really one: a test must be able to pin the day (a suite that
  /// depends on the wall clock fails at midnight and passes on the retry), and
  /// there must be exactly one answer to "what day is it" on a screen that files
  /// nine things under it. Standards §3 bans string-literal user constants for the
  /// same reason — a value the app reasons about belongs somewhere it can be
  /// overridden.
  ///
  /// **Local, deliberately.** The strap counts steps to ITS local midnight and the
  /// store files rows by local calendar date, so the day the owner is living in is
  /// the only one that lines up. `DateTime.now().toUtc()` here would show an
  /// Asia/Kolkata owner yesterday's steps for the first five and a half hours of
  /// every day.
  TodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return today(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$todayHash() => r'9501cf757711783efc628687ab228f4259298a1b';
