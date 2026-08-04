/// Turns the platform's lifecycle into the one question the link cares about:
/// is this app in front?
///
/// ## Why `AppLifecycleListener` and not `WidgetsBindingObserver`
///
/// Three reasons, and the third is the one that decided it.
///
///   1. **It names the transitions.** `onResume` / `onPause` are the events;
///      `didChangeAppLifecycleState` is a switch over five states that every
///      reader has to re-derive the transitions from. The bug this file exists
///      to avoid — releasing the link on a transient `inactive` (a notification
///      shade, an incoming call) and thrashing the radio — is one line of
///      difference in the first form and a subtle reading of the second.
///   2. **It is disposable on its own.** `dispose()` removes the observer, so
///      the listener's lifetime is an object's lifetime.
///   3. **It does not need a widget.** `WidgetsBindingObserver` is a mixin on a
///      `State`, so observing lifecycle that way binds the strap connection to
///      a widget that the router can rebuild or replace. The link must outlive
///      every screen — it is held by a `keepAlive` provider — and a
///      widget-shaped lifetime is the wrong lifetime for it.
///
/// ## Which transitions
///
/// Foreground on `onResume` (visible AND taking input). Background on `onPause`
/// and `onDetach`, deliberately NOT on `onInactive` or `onHide`: `inactive`
/// fires for a pulled-down notification shade and for the app switcher, and
/// dropping an authenticated session for those means reconnecting seconds later,
/// twice, for nothing.
library;

import 'package:flutter/widgets.dart';

/// Reports foreground and background to whoever holds the strap.
class ForegroundWatch {
  /// [onForeground] and [onBackground] are called on the transitions above.
  ///
  /// Nothing is observed until [start] — a constructor that fired [onForeground]
  /// would call back into an object that is still being built.
  ForegroundWatch({
    required this.onForeground,
    required this.onBackground,
    WidgetsBinding? binding,
  }) : _binding = binding ?? WidgetsBinding.instance;

  /// The app became visible and interactive.
  final VoidCallback onForeground;

  /// The app was backgrounded or is being torn down.
  final VoidCallback onBackground;

  final WidgetsBinding _binding;
  AppLifecycleListener? _listener;

  /// Starts observing, and reports the state the app is ALREADY in.
  ///
  /// The second half matters as much as the first: a lifecycle listener reports
  /// transitions, and this object is created lazily — the first time something
  /// watches the sync controller, which happens with the app already resumed.
  /// Without the immediate report, the link would sit closed until the owner
  /// backgrounded the app and came back.
  ///
  /// A null `lifecycleState` is the window before the platform has reported in
  /// at all; it is treated as foreground because that is what launching an app
  /// is. The worst case is one connect attempt that a `onPause` immediately
  /// releases, which is the safe direction to be wrong in.
  void start() {
    if (_listener != null) {
      return;
    }
    _listener = AppLifecycleListener(
      binding: _binding,
      onResume: onForeground,
      onPause: onBackground,
      onDetach: onBackground,
    );
    final state = _binding.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      onForeground();
    }
  }

  /// Stops observing. Idempotent.
  void dispose() {
    _listener?.dispose();
    _listener = null;
  }
}
