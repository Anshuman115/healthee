// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The running conversation with the coach.

@ProviderFor(CoachController)
final coachControllerProvider = CoachControllerProvider._();

/// The running conversation with the coach.
final class CoachControllerProvider
    extends $NotifierProvider<CoachController, CoachConversation> {
  /// The running conversation with the coach.
  CoachControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachControllerHash();

  @$internal
  @override
  CoachController create() => CoachController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachConversation value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachConversation>(value),
    );
  }
}

String _$coachControllerHash() => r'cfc2acab7ec5e58b0afbf53d97a6e9e960dcbad6';

/// The running conversation with the coach.

abstract class _$CoachController extends $Notifier<CoachConversation> {
  CoachConversation build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CoachConversation, CoachConversation>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoachConversation, CoachConversation>,
              CoachConversation,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
