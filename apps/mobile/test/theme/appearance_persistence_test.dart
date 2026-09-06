import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/appearance_colors.dart';
import 'package:healthee/core/theme/appearance_preferences.dart';
import 'package:healthee/core/theme/appearance_variant.dart';
import 'package:healthee/core/theme/theme_controller.dart';

void main() {
  test('appearance choices persist across provider containers', () async {
    final first = ProviderContainer();
    first.read(themeControllerProvider.notifier).set(ThemeMode.dark);
    first
        .read(appearanceControllerProvider.notifier)
        .set(
          const AppearanceVariant(
            accent: 4,
            background: BackgroundVariant.amoled,
          ),
        );
    await Future<void>.delayed(Duration.zero);
    expect(
      await first.read(appearancePreferencesProvider).read('theme_mode'),
      'dark',
    );
    first.dispose();
    final next = ProviderContainer();
    addTearDown(next.dispose);
    next.read(themeControllerProvider);
    next.read(appearanceControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(next.read(themeControllerProvider), ThemeMode.dark);
    final variant = next.read(appearanceControllerProvider);
    expect(variant.accent, 4);
    expect(variant.background, BackgroundVariant.amoled);
    expect(appearanceColors(Brightness.dark, variant).bg, Colors.black);
  });
}
