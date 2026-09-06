import 'package:flutter/material.dart';
import 'package:healthee/core/theme/appearance_variant.dart';
import 'package:healthee/core/theme/palette.dart';
import 'package:healthee/core/theme/tokens.dart';

HealtheeColors appearanceColors(
  Brightness brightness,
  AppearanceVariant variant,
) {
  final dark = brightness == Brightness.dark;
  var colors = dark
      ? const HealtheeColors.dark()
      : const HealtheeColors.light();
  final accent = AppearancePalette.accents[variant.accent][dark ? 1 : 0];
  if (variant.accent != 0) {
    colors = colors.copyWith(
      accent: accent,
      accent2: accent,
      accentSoft: accent.withValues(alpha: 0.12),
    );
  }
  if (dark && variant.background != BackgroundVariant.espresso) {
    final black = variant.background == BackgroundVariant.amoled;
    colors = colors.copyWith(
      bg: black ? AppearancePalette.blackBg : AppearancePalette.neutralBg,
      surface: black
          ? AppearancePalette.blackSurface
          : AppearancePalette.neutralSurface,
      surface2: black
          ? AppearancePalette.blackBg
          : AppearancePalette.neutralSunken,
      chrome: black ? AppearancePalette.blackBg : AppearancePalette.neutralBg,
      line: black ? AppearancePalette.blackLine : AppearancePalette.neutralLine,
      line2: black
          ? AppearancePalette.blackLine2
          : AppearancePalette.neutralLine2,
    );
  }
  return colors;
}
