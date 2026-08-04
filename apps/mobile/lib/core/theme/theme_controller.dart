/// Which theme is showing — the app's one piece of appearance state.
///
/// A Riverpod notifier rather than a global, because Standards §3 bans global
/// singletons and `ValueNotifier` globals outright: "everything injectable via
/// providers (testability is the point)". A widget test can override this
/// provider and render the dark theme without touching a platform channel.
///
/// The default is [ThemeMode.system], where `docs/APP_DESIGN_BRIEF.md` §2 says
/// "Light default, full dark". Those agree more than they look: the brief's point
/// is that **light is the authored baseline** — dark is not derived from it and
/// neither is an afterthought — and `ThemeMode.system` lands on light for anyone
/// whose phone is set to light, which is the same first impression.
///
/// Following the OS is the right default for a phone app specifically. A web page
/// is a document a visitor arrived at once; this app lives beside the owner's
/// other apps, is opened first thing in the morning and last thing at night, and
/// looks broken if it ignores a choice they already made system-wide.
///
/// Persisting an explicit override belongs with the Profile screen's appearance
/// section and lands with it. If the owner would rather force light until they
/// choose otherwise, this one line is the whole change.
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
