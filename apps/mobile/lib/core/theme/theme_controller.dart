/// Which theme is showing — the app's one piece of appearance state.
///
/// A Riverpod notifier rather than a global, because Standards §3 bans global
/// singletons and `ValueNotifier` globals outright: "everything injectable via
/// providers (testability is the point)". A widget test can override this
/// provider and render the dark theme without touching a platform channel.
///
/// The default is [ThemeMode.system], which differs from the landing page (light,
/// ignoring the OS). That is not drift — it is the same principle applied to a
/// different surface. A web page is a document the visitor arrived at; a phone app
/// lives beside the owner's other apps and looks wrong if it ignores the choice
/// they already made system-wide. Persisting an explicit override belongs with the
/// Profile screen's appearance section and lands with it.
library;

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_controller.g.dart';

/// The active theme mode.
@riverpod
class ThemeController extends _$ThemeController {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Switches the app's appearance.
  void set(ThemeMode mode) => state = mode;
}
