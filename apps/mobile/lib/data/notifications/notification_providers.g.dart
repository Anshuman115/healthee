// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationService)
final notificationServiceProvider = NotificationServiceProvider._();

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
  NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'86b10b6e0b5a9ce20fae66de8d60f7de4fd69aac';

@ProviderFor(notificationDestination)
final notificationDestinationProvider = NotificationDestinationProvider._();

final class NotificationDestinationProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  NotificationDestinationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationDestinationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationDestinationHash();

  @$internal
  @override
  $StreamProviderElement<String> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String> create(Ref ref) {
    return notificationDestination(ref);
  }
}

String _$notificationDestinationHash() =>
    r'f5c3b3aa4144bf229a6e73f0c6a5ee917362dab0';

@ProviderFor(notificationLifecycle)
final notificationLifecycleProvider = NotificationLifecycleProvider._();

final class NotificationLifecycleProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  NotificationLifecycleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationLifecycleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationLifecycleHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return notificationLifecycle(ref);
  }
}

String _$notificationLifecycleHash() =>
    r'd9d42d6004d6c94b097d4f9ce1448240af505680';

@ProviderFor(reminderPreferences)
final reminderPreferencesProvider = ReminderPreferencesProvider._();

final class ReminderPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReminderPreferences>,
          ReminderPreferences,
          FutureOr<ReminderPreferences>
        >
    with
        $FutureModifier<ReminderPreferences>,
        $FutureProvider<ReminderPreferences> {
  ReminderPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderPreferencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<ReminderPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReminderPreferences> create(Ref ref) {
    return reminderPreferences(ref);
  }
}

String _$reminderPreferencesHash() =>
    r'6e3872f3ae2ceb7baf64b4d4cf52e715efb0abf3';
