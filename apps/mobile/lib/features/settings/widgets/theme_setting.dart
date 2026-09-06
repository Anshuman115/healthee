/// Appearance — the same state the header toggle writes, not a second copy.
///
/// `ThemeToggleButton` (in `shared/page_head.dart`) is a two-way switch that
/// reads the brightness actually being rendered and asks for the opposite. It
/// stays where legacy put it, because it is the control you want when the room
/// changes and you are already looking at a chart.
///
/// This row is the other question — *which mode is this app in* — and it can
/// express the one the button cannot: `ThemeMode.system`, following the phone.
/// Both write `themeControllerProvider` and neither holds a copy, so tapping the
/// header button moves this row and choosing a mode here moves the header button.
/// A `bool` in either widget's `State` would have been the second definition that
/// makes them disagree in exactly one direction, once, on somebody's phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/appearance_preferences.dart';
import 'package:healthee/core/theme/appearance_variant.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/theme_controller.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Light · Dark · System, with the current one selected.
class ThemeSetting extends ConsumerWidget {
  /// The appearance row.
  const ThemeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final variant = ref.watch(appearanceControllerProvider);
    final error = ref.watch(appearanceErrorProvider);
    final mode = ref.watch(themeControllerProvider);
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          SegmentedButton<ThemeMode>(
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
              ),
            ],
            selected: <ThemeMode>{mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                ref.read(themeControllerProvider.notifier).set(selection.first),
          ),
          DropdownButton<int>(
            value: variant.accent,
            isExpanded: true,
            items: [
              for (var i = 0; i < AppearanceVariant.accentNames.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(AppearanceVariant.accentNames[i]),
                ),
            ],
            onChanged: (v) => ref
                .read(appearanceControllerProvider.notifier)
                .set(
                  AppearanceVariant(accent: v!, background: variant.background),
                ),
          ),
          DropdownButton<BackgroundVariant>(
            value: variant.background,
            isExpanded: true,
            items: [
              for (final v in BackgroundVariant.values)
                DropdownMenuItem(
                  value: v,
                  child: Text('Dark background: ${v.name}'),
                ),
            ],
            onChanged: (v) => ref
                .read(appearanceControllerProvider.notifier)
                .set(AppearanceVariant(accent: variant.accent, background: v!)),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            // Says what the default does rather than leaving "System" to be
            // guessed at, and says the one true limitation: nothing persists it.
            error ??
                'System follows your phone. Your choices are saved on this phone.',
            style: text.bodySmall?.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }
}
