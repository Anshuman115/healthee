// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'milestones.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(milestones)
final milestonesProvider = MilestonesProvider._();

final class MilestonesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Challenge>>,
          List<Challenge>,
          FutureOr<List<Challenge>>
        >
    with $FutureModifier<List<Challenge>>, $FutureProvider<List<Challenge>> {
  MilestonesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'milestonesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$milestonesHash();

  @$internal
  @override
  $FutureProviderElement<List<Challenge>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Challenge>> create(Ref ref) {
    return milestones(ref);
  }
}

String _$milestonesHash() => r'25daf30dc8a9a3ee40e56b17f234e4ac7f5f66fe';
