// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'view_date.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The owner-local calendar date the screens are showing, `YYYY-MM-DD`.
///
/// `keepAlive` for the reason the selection exists at all: it **follows the
/// reader between screens**, which it cannot do if it is disposed the moment the
/// last screen watching it is rebuilt.

@ProviderFor(ViewDate)
final viewDateProvider = ViewDateProvider._();

/// The owner-local calendar date the screens are showing, `YYYY-MM-DD`.
///
/// `keepAlive` for the reason the selection exists at all: it **follows the
/// reader between screens**, which it cannot do if it is disposed the moment the
/// last screen watching it is rebuilt.
final class ViewDateProvider extends $NotifierProvider<ViewDate, String> {
  /// The owner-local calendar date the screens are showing, `YYYY-MM-DD`.
  ///
  /// `keepAlive` for the reason the selection exists at all: it **follows the
  /// reader between screens**, which it cannot do if it is disposed the moment the
  /// last screen watching it is rebuilt.
  ViewDateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewDateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewDateHash();

  @$internal
  @override
  ViewDate create() => ViewDate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$viewDateHash() => r'7d669de2d1c0705ef4072fc100450fd16cd7675a';

/// The owner-local calendar date the screens are showing, `YYYY-MM-DD`.
///
/// `keepAlive` for the reason the selection exists at all: it **follows the
/// reader between screens**, which it cannot do if it is disposed the moment the
/// last screen watching it is rebuilt.

abstract class _$ViewDate extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
