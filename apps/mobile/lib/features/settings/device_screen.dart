/// Your Helio Strap — `H.screens.device`, on the real pairing and sync state.
///
/// ```js
/// H.screens.device = () => `${H.header('Your Helio Strap.','Connected device',true)}
///   <div class="device-visual">${H.icon('strap')}</div>
///   <div class="center"><h2>Amazfit Helio Strap</h2><p class="small section">…</p></div>
///   <div class="card section"><div class="two">${two stats}</div>
///     <hr class="divider"><p class="small">…</p></div>
///   <div class="section">${H.button('Sync now','sync','full','sync')}</div>
///   <div class="card flush section">${two rows}</div>
///   ${H.footer()}`;
/// ```
///
/// ## Stop lives here, and it had to live somewhere
///
/// The deleted connection strip carried a **Stop** while a sync was running, for
/// a reason it stated plainly: *"the strap accepts one connection at a time and
/// a sync the owner cannot end is a phone they have to background to escape."*
/// The ring that replaced the strip takes no gesture, so the control needed a
/// home rather than a deletion, and this is the strap's own screen.
///
/// It is drawn **only while a sync is running**, so it is never a dead control,
/// and it says what it will do — `cancel()` stops at the next phase boundary
/// rather than aborting mid-fetch.
///
/// ## Unpair is routed to, not re-implemented
///
/// `features/pairing/` owns the credential lifecycle and Standards §3 forbids
/// reaching into it. A second unpair here would be a second place the keystore
/// is cleared from.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/features/settings/strap_lines.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/emblems.dart';
import 'package:healthee/shared/v02/list_row.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/stat_block.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

/// The paired strap: what is held, what it last said, and the way to change it.
class DeviceScreen extends ConsumerWidget {
  /// [now] is injected by tests so the freshness label is deterministic.
  const DeviceScreen({this.now, super.key});

  /// The prototype's own h1.
  static const String title = 'Your Helio Strap';

  /// Its eyebrow.
  static const String eyebrow = 'Connected device';

  /// The one device this app talks to.
  static const String deviceName = 'Amazfit Helio Strap';

  /// `.two { gap: 12px }`.
  static const double columnGap = 12;

  /// The instant "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final at = now ?? DateTime.now();
    final strap = ref.watch(pairingSummaryProvider).value?.strap;
    final day = ref.watch(deviceDayProvider).value;
    final link = ref.watch(syncControllerProvider);
    final syncing = link.isBusy;
    final lastSync = day?.sync.lastCompleteSync;
    return SettingsPage(
      title: title,
      eyebrow: eyebrow,
      children: <Widget>[
        const DeviceVisual(),
        Center(
          child: Text(
            deviceName,
            style: FormType.heading2.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(height: SectionGap.height),
        SmallProse(
          strap == null
              ? 'No strap paired'
              : syncing
                  ? 'Reading from your strap now'
                  : 'Paired · ${strap.mac}',
          centred: true,
        ),
        const SectionGap(),
        PlainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: StatBlock(
                      label: day?.batteryPercent == null
                          ? 'Battery unavailable'
                          : 'Battery at that sync',
                      value: day?.batteryPercent?.toString(),
                      unit: '%',
                    ),
                  ),
                  const SizedBox(width: columnGap),
                  Expanded(
                    child: StatBlock(
                      label: 'Last full sync',
                      value: lastSync == null
                          ? null
                          : ageLabel(lastSync, now: at),
                    ),
                  ),
                ],
              ),
              const CardDivider(),
              // The two sentences are the behaviour; `strap_lines.dart` owns
              // them and says why each one is worded as it is.
              SmallProse(strapLines(day, now: at).join(' ')),
            ],
          ),
        ),
        const SectionGap(),
        HButton(
          label: 'Sync now',
          icon: SolarIconsOutline.refresh,
          onPressed: syncing
              ? null
              : () => unawaited(
                  ref.read(syncControllerProvider.notifier).syncNow(),
                ),
        ),
        // Drawn only while something is running, so it is never a dead control.
        if (syncing) ...<Widget>[
          const SizedBox(height: columnGap),
          HButton(
            label: 'Stop at the next step',
            kind: HButtonKind.secondary,
            onPressed: ref.read(syncControllerProvider.notifier).cancel,
          ),
        ],
        const SectionGap(),
        FlushCard(
          children: <Widget>[
            ListRow(
              icon: SolarIconsOutline.refresh,
              title: 'Data & sync details',
              subtitle: 'See which streams are up to date',
              onTap: () => unawaited(context.push(Routes.dataFreshness)),
            ),
            ListRow(
              icon: SolarIconsOutline.watchRound,
              title: strap == null ? 'Connect a strap' : 'Pairing and unpair',
              subtitle: strap == null
                  ? 'Find your strap and confirm its key'
                  : 'What is held, and how to forget it',
              onTap: () => unawaited(context.push(Routes.pairing)),
            ),
          ],
        ),
        const DataFooter(),
      ],
    );
  }
}
