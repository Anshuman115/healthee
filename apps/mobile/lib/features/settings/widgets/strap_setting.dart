/// Your strap — what is paired, what it last said, and the way to unpair.
///
/// Three facts, from three different places, and they are three because they
/// answer different questions:
///
/// ```text
///   paired      the keystore    is there a strap this app may talk to at all
///   last sync   the local store when did a pull last FINISH — not "was attempted"
///   battery     the local store what the band reported at that sync
/// ```
///
/// **`lastCompleteSync`, never `lastAttempt`.** `data/device/device_day.dart`
/// keeps both and they are not interchangeable: an attempt that failed halfway
/// leaves data unread, and reporting it as a sync is the stale-behind-a-healthy-
/// screen failure the data-health strip exists to prevent, one screen over.
///
/// **The battery is dated by that same sync and says so.** A percentage with no
/// instant beside it is a claim about now made from a reading that may be a day
/// old — the strap is not connected while this screen is open, so there is no
/// fresher number to be had and pretending otherwise is not available.
///
/// **Unpair is routed to, not re-implemented.** `features/pairing/` owns the
/// credential lifecycle and Standards §3 forbids reaching into it; a second
/// unpair here would be a second place the keystore is cleared from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The paired strap, its last complete read, and its battery at that read.
class StrapSetting extends ConsumerWidget {
  /// [now] is injected by tests so the freshness label is deterministic.
  const StrapSetting({this.now, super.key});

  /// The instant "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final at = now ?? DateTime.now();
    final strap = ref.watch(pairingSummaryProvider).value?.strap;
    final day = ref.watch(deviceDayProvider).value;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your strap', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Text(strap == null ? 'No strap paired' : 'Paired', style: text.titleSmall),
          if (strap?.mac case final String mac) ...[
            const SizedBox(height: Insets.xs),
            Text(mac, style: text.bodySmall?.copyWith(color: colors.ink2)),
          ],
          const SizedBox(height: Insets.sm),
          Text(
            strapLines(day, now: at).join('\n'),
            style: text.bodySmall?.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => context.go(Routes.pairing),
              child: Text(strap == null ? 'Pair a strap' : 'Pairing and unpair'),
            ),
          ),
        ],
      ),
    );
  }
}

/// What is known about the last read. Public so a test can pin the sentences.
///
/// A list rather than one string so the two facts stay separable: a phone with a
/// sync and no battery reading is an ordinary state, and a joined sentence would
/// need a branch per combination.
List<String> strapLines(DeviceDay? day, {required DateTime now}) {
  if (day == null) {
    return const <String>["Reading this phone's own store…"];
  }
  return <String>[
    switch (day.sync.lastCompleteSync) {
      final DateTime last => 'Last full sync ${ageLabel(last, now: now)}.',
      // Not "never synced" phrased as a fault: a phone that has just been paired
      // is in this state for a minute and nothing is wrong with it.
      _ => 'No sync has finished on this phone yet.',
    },
    switch (day.batteryPercent) {
      final int percent => 'Battery $percent% at that sync.',
      _ => 'The band has not reported its battery.',
    },
  ];
}
