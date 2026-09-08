library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/appearance_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_controller.g.dart';

/// The active theme mode.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  int _revision = 0;
  Future<void> _pending = Future<void>.value();
  @override
  ThemeMode build() {
    final storage = ref.watch(appearancePreferencesProvider);
    final revision = _revision;
    unawaited(_restore(storage, revision));
    return ThemeMode.system;
  }

  Future<void> _restore(AppearancePreferences storage, int revision) async {
    try {
      final saved = await storage.read('theme_mode');
      if (ref.mounted && revision == _revision) {
        state =
            ThemeMode.values.where((v) => v.name == saved).firstOrNull ??
            ThemeMode.system;
      }
    } on Exception catch (error, stack) {
      _failed(error, stack);
    }
  }

  /// Switches the app's appearance.
  void set(ThemeMode mode) {
    ++_revision;
    state = mode;
    final storage = ref.read(appearancePreferencesProvider);
    _pending = _pending
        .then((_) => storage.write('theme_mode', mode.name))
        .then<void>((_) {
          if (ref.mounted) {
            ref.read(appearanceErrorProvider.notifier).report(null);
          }
        })
        .onError<Exception>(_failed);
  }

  void _failed(Exception error, StackTrace stack) {
    AppLog.failure('appearance', 'persisting theme mode', error, stack);
    if (ref.mounted) {
      ref
          .read(appearanceErrorProvider.notifier)
          .report('Appearance could not be saved. Choose it again to retry.');
    }
  }
}
