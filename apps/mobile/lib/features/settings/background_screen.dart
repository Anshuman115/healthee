/// Background sync — `H.screens.background`, on the real scheduler record.
///
/// ```js
/// H.screens.background = () => `${H.header('Connected, quietly.','Background sync',true)}
///   <p class="small">…</p>
///   <div class="card flush section">${four toggles}</div>
///   <div class="card section">${two selects}<p class="small">…</p></div>
///   ${H.link('View sync status','sync','button secondary full section')}
///   ${H.footer()}`;
/// ```
///
/// ## THREE switches, not the prototype's four
///
/// The prototype draws `Background collection` and `Background upload` as two
/// independent switches. `BackgroundPreferences` has **one** `enabled` flag
/// covering both directions — the scheduler registers one periodic job that
/// pulls and then pushes — so two switches here would be two controls writing
/// one field, and turning either "off" would silently turn the other off too.
///
/// That is precisely the *"two definitions of one thing"* failure this product
/// is built against, so the fourth switch is not drawn and the remaining one
/// says what it actually governs. Splitting the flag is a data-layer change with
/// its own tests, not a presentation one, and it is not this work package.
///
/// The two intervals and the two network limits are unchanged and still write
/// the same record through the same scheduler.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/background/background_preferences.dart';
import 'package:healthee/data/background/background_scheduler.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/fields.dart';
import 'package:healthee/shared/v02/list_row.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:healthee/shared/v02/toggle_row.dart';
import 'package:solar_icons/solar_icons.dart';

/// Whether the phone works on its own, how often, and under what limits.
class BackgroundScreen extends ConsumerWidget {
  /// The background-sync screen.
  const BackgroundScreen({super.key});

  /// The prototype's own h1.
  static const String title = 'Connected, quietly.';

  /// Its eyebrow.
  static const String eyebrow = 'Background sync';

  /// The line under the header.
  static const String opening =
      'Your phone can collect from the strap and upload to your server in the '
      'background.';

  /// The one true limitation, said where the intervals are chosen.
  static const String note =
      'Your operating system decides the exact timing. The intervals are '
      'preferences, not guarantees, and Bluetooth permission must already be '
      'granted. Sync now stays manual.';

  /// `Every 30 minutes` / `Every 3 hours`, from a count of minutes.
  static String intervalLabel(int minutes) {
    if (minutes < 60) {
      return 'Every $minutes minutes';
    }
    final hours = minutes ~/ 60;
    return hours == 1 ? 'Every hour' : 'Every $hours hours';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsPage(
      title: title,
      eyebrow: eyebrow,
      children: <Widget>[
        const SmallProse(opening),
        const SectionGap(),
        AccountAsyncView<BackgroundPreferences>(
          value: ref.watch(backgroundPreferencesProvider),
          onRetry: () => ref.invalidate(backgroundPreferencesProvider),
          builder: (context, value) => _Editor(
            key: ValueKey<String>(value.encode()),
            value: value,
            save: (next) async {
              await ref.read(backgroundSchedulerProvider).save(next);
              ref.invalidate(backgroundPreferencesProvider);
            },
          ),
        ),
        const SectionGap(),
        AccountAsyncView<String?>(
          value: ref.watch(backgroundLastRunProvider),
          onRetry: () => ref.invalidate(backgroundLastRunProvider),
          builder: (context, value) => FlushCard(
            children: <Widget>[
              ListRow(
                icon: SolarIconsOutline.history,
                title: 'Last background attempt',
                // Not "never ran" phrased as a fault: a phone that has just
                // been set up is in this state until the first window comes up.
                subtitle: value ?? 'No background job has run yet.',
                onTap: () => ref.invalidate(backgroundLastRunProvider),
                trailing: const Icon(SolarIconsOutline.refresh, size: 16),
              ),
            ],
          ),
        ),
        const SectionGap(),
        HButton(
          label: 'View sync status',
          kind: HButtonKind.secondary,
          onPressed: () => unawaited(context.push(Routes.dataFreshness)),
        ),
        const DataFooter(),
      ],
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({required this.value, required this.save, super.key});

  final BackgroundPreferences value;
  final Future<void> Function(BackgroundPreferences) save;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late bool _enabled = widget.value.enabled;
  late bool _wifi = widget.value.wifiOnly;
  late bool _charging = widget.value.chargingOnly;
  late int _pull = widget.value.pullMinutes;
  late int _push = widget.value.pushMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FlushCard(
          children: <Widget>[
            ToggleRow(
              // One switch, because there is one flag. See the library
              // docstring for why the prototype's fourth is not drawn.
              title: 'Background collection and upload',
              body: 'Bring new readings from your strap, and send them on.',
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            ToggleRow(
              title: 'Unmetered networks only',
              body: 'Wait for Wi-Fi or an unmetered connection.',
              value: _wifi,
              onChanged: (value) => setState(() => _wifi = value),
            ),
            ToggleRow(
              title: 'Only while charging',
              body: 'Save background work for when plugged in.',
              value: _charging,
              onChanged: (value) => setState(() => _charging = value),
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
                label: 'Collection interval',
                child: HSelect<int>(
                  value: _pull,
                  onChanged: (value) =>
                      setState(() => _pull = value ?? _pull),
                  items: <(int, String)>[
                    for (final int minutes in BackgroundPreferences.pullOptions)
                      (minutes, BackgroundScreen.intervalLabel(minutes)),
                  ],
                ),
              ),
              HField(
                label: 'Upload interval',
                child: HSelect<int>(
                  value: _push,
                  onChanged: (value) =>
                      setState(() => _push = value ?? _push),
                  items: <(int, String)>[
                    for (final int minutes in BackgroundPreferences.pushOptions)
                      (minutes, BackgroundScreen.intervalLabel(minutes)),
                  ],
                ),
              ),
              const SmallProse(BackgroundScreen.note),
            ],
          ),
        ),
        const SizedBox(height: SectionGap.height),
        ServerActionButton(
          label: 'Save background settings',
          style: ActionButtonStyle.v02,
          action: () => widget.save(
            BackgroundPreferences(
              enabled: _enabled,
              pullMinutes: _pull,
              pushMinutes: _push,
              wifiOnly: _wifi,
              chargingOnly: _charging,
            ),
          ),
          onSaved: () {},
        ),
      ],
    );
  }
}
