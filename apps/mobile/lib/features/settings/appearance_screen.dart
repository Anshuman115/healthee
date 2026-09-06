/// Appearance — `H.screens.appearance`, on the app's one theme state.
///
/// ```js
/// H.screens.appearance = () => `${H.header('A quieter view.','Appearance',true)}
///   <h3>Choose your light.</h3><p class="small section">…</p>
///   <div class="theme-options section">…</div>
///   ${H.section('A preview of your day', …)}
///   ${H.section('Gentle by default', …)}
///   ${H.footer()}`;
/// ```
///
/// ## Still one source of truth, one screen further away
///
/// `theme_setting.dart` recorded the rule and this keeps it verbatim: the tiles
/// read `themeControllerProvider` and write `themeControllerProvider`, and hold
/// nothing. `ThemeOptions` is stateless for exactly that reason (see its own
/// docstring). Tapping the header toggle on Today moves these tiles; choosing a
/// tile here moves that button. Two copies could not do that, and the one that
/// drifted would drift in one direction, once, on somebody's phone.
///
/// ## Two controls the prototype has no tile for
///
/// The accent and the dark-background variant. They exist, they persist, and
/// dropping them to match a prototype that never drew them would be deleting
/// working behaviour to win a pixel — which the brief's *"keep the behaviour;
/// replace the presentation"* forbids. They are drawn as two `.field` selects,
/// the prototype's own form geometry, in a card directly under the tiles.
///
/// ## The preview draws the owner's data or nothing
///
/// `H.screens.appearance` fills its preview card with the prototype's bundled
/// HRV sample. We have no bundled sample and will not invent one: the section
/// renders the owner's own overnight HRV when the server has sent a fortnight of
/// it, and **renders nothing at all** when it has not. An empty chart under the
/// heading *"A preview of your day"* would be a claim about a day.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/appearance_preferences.dart';
import 'package:healthee/core/theme/appearance_variant.dart';
import 'package:healthee/core/theme/theme_controller.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/charts/v02/v02_sparkline.dart';
import 'package:healthee/shared/states/current_account_value.dart';
import 'package:healthee/shared/v02/fields.dart';
import 'package:healthee/shared/v02/notices.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/stat_block.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:healthee/shared/v02/theme_options.dart';

/// Light · Dark · System, the accent, and a preview of the result.
class AppearanceScreen extends ConsumerWidget {
  /// The appearance screen.
  const AppearanceScreen({super.key});

  /// The prototype's own h1.
  static const String title = 'A quieter view.';

  /// Its eyebrow.
  static const String eyebrow = 'Appearance';

  /// The prototype's own heading over the tiles.
  static const String prompt = 'Choose your light.';

  /// And its sentence.
  static const String promptBody =
      'The same familiar app, comfortable at any hour.';

  /// `.section { margin-top: 24px }` between the prose and the tiles.
  static const double promptGap = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mode = ref.watch(themeControllerProvider);
    final variant = ref.watch(appearanceControllerProvider);
    final failure = ref.watch(appearanceErrorProvider);
    final snapshot = currentAccountValue(
      ref.watch(todaySnapshotProvider),
    ).value?.snapshot;
    return SettingsPage(
      title: title,
      eyebrow: eyebrow,
      children: <Widget>[
        Text(prompt, style: FormType.heading3.copyWith(color: colors.ink)),
        const SmallProse(promptBody),
        const SizedBox(height: promptGap),
        ThemeOptions<ThemeMode>(
          selected: mode,
          onSelected: ref.read(themeControllerProvider.notifier).set,
          options: const <ThemeOption<ThemeMode>>[
            ThemeOption<ThemeMode>(
              value: ThemeMode.light,
              icon: Icons.wb_sunny_outlined,
              label: 'Light',
            ),
            ThemeOption<ThemeMode>(
              value: ThemeMode.dark,
              icon: Icons.nightlight_outlined,
              label: 'Dark',
            ),
            ThemeOption<ThemeMode>(
              value: ThemeMode.system,
              icon: Icons.settings_outlined,
              label: 'System',
            ),
          ],
        ),
        const SectionGap(),
        PlainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HField(
                label: 'Accent',
                child: HSelect<int>(
                  value: variant.accent,
                  onChanged: (value) => _setVariant(
                    ref,
                    AppearanceVariant(
                      accent: value ?? variant.accent,
                      background: variant.background,
                    ),
                  ),
                  items: <(int, String)>[
                    for (
                      var i = 0;
                      i < AppearanceVariant.accentNames.length;
                      i++
                    )
                      (i, AppearanceVariant.accentNames[i]),
                  ],
                ),
              ),
              HField(
                label: 'Dark background',
                // Says what the default does rather than leaving "System" to be
                // guessed at, and says the one true limitation: where it is kept.
                hint: failure ??
                    'System follows your phone. Your choices are saved on '
                        'this phone.',
                child: HSelect<BackgroundVariant>(
                  value: variant.background,
                  onChanged: (value) => _setVariant(
                    ref,
                    AppearanceVariant(
                      accent: variant.accent,
                      background: value ?? variant.background,
                    ),
                  ),
                  items: <(BackgroundVariant, String)>[
                    for (final BackgroundVariant option
                        in BackgroundVariant.values)
                      (option, option.name),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._preview(snapshot),
        const SectionGap(),
        const SectionHead(title: 'Gentle by default'),
        PlainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Motion that knows when to be quiet.',
                style: FormType.heading3.copyWith(color: colors.ink),
              ),
              const SizedBox(height: promptGap),
              const SmallProse(
                'Brief transitions keep your place. Charts animate once and '
                'stay put on the way back. Your phone’s reduced-motion '
                'setting stops them entirely.',
              ),
            ],
          ),
        ),
        const DataFooter(),
      ],
    );
  }

  void _setVariant(WidgetRef ref, AppearanceVariant next) =>
      ref.read(appearanceControllerProvider.notifier).set(next);

  /// The preview section, or **nothing** — see the library docstring.
  List<Widget> _preview(TodaySnapshot? snapshot) {
    final points = <double?>[
      for (final TrendPoint point
          in snapshot?.sparkline(TodayMetricIds.heartRateVariability) ??
              const <TrendPoint>[])
        point.value,
    ];
    if (points.length < 2) {
      return const <Widget>[];
    }
    final latest = points.last;
    return <Widget>[
      const SectionGap(),
      const SectionHead(title: 'A preview of your day'),
      ToneScope(
        tone: Tone.fitness,
        child: PlainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  StatBlock(
                    label: 'Overnight HRV',
                    value: latest?.round().toString(),
                    unit: 'ms',
                  ),
                  const HBadge('Your own nights', kind: BadgeKind.accent),
                ],
              ),
              const SizedBox(height: promptGap),
              // Progress 1: this strip is a specimen of the theme, not a
              // reveal — there is nothing on this screen to reveal it against.
              V02Sparkline(points, progress: 1, height: 48),
            ],
          ),
        ),
      ),
    ];
  }
}
