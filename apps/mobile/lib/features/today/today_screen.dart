/// Today — what the strap measured, and what the server made of it.
///
/// Composition only. The frame, the two data sources, the failure rules and the
/// reveal registry all live in `shared/instrument_screen.dart`, which four other
/// screens use for the same reasons; `today_sections.dart` decides what Today
/// shows and in what order. This file is the wiring between them plus the three
/// things only Today watches — the push stamp, the server session, and the
/// classified connection state those two feed.
///
/// ## The connection surface is assembled here, from one classification
///
/// `connectionHealth(...)` is called once, in this build, and the answer goes to
/// two places: the strip above the scroll (which draws nothing when the answer is
/// quiet) and the dot in the header row (which is drawn only when it is). One
/// call, two readers — see `shared/connection/connection_strip.dart` for why that
/// asymmetry is deliberate and why neither widget may decide "quiet" for itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/shared/connection/connection_strip.dart';
import 'package:healthee/shared/instrument_screen.dart';

/// The push state, for the data-health strip. Re-read whenever Today is.
final _pushStampProvider = FutureProvider<PushStamp>((ref) {
  return ref.watch(localStoreProvider).pushReader.lastAttempt();
});

/// The app's home screen.
class TodayScreen extends ConsumerWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const TodayScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = now ?? DateTime.now();
    final push = ref.watch(_pushStampProvider).value;
    // `.value?.signedIn` and not `.requireValue`: while the keystore read is in
    // flight this is null, which the data-health strip reads as "not yet known"
    // and stays silent about. Guessing "signed out" for a frame would flash an
    // invitation at an owner who already is.
    final signedIn = ref.watch(serverSessionProvider).value?.signedIn;
    final health = connectionHealth(
      link: ref.watch(syncControllerProvider),
      now: at,
      push: push,
      signedIn: signedIn,
      lastStrapSync: ref.watch(deviceDayProvider).value?.sync.lastCompleteSync,
    );
    final controller = ref.read(syncControllerProvider.notifier);
    return InstrumentScreen(
      now: now,
      // Above the scroll, and absent entirely while the answer is quiet: a
      // connection state that scrolls away is one the owner cannot check when
      // they need it, and one that is always there is one they stop reading.
      chrome: ConnectionStrip(
        health: health,
        // The same un-debounced path pull-to-refresh takes. `syncNow` is never
        // debounced by design — an explicit request is not a heuristic.
        onRetry: controller.syncNow,
        onStop: controller.cancel,
      ),
      onRefreshed: () => ref.invalidate(_pushStampProvider),
      sections: (data) => todaySections(
        data,
        TodayExtras(
          push: push,
          signedIn: signedIn,
          health: health,
          onSignIn: () => context.go(Routes.serverSignIn),
          onOpen: context.go,
        ),
      ),
    );
  }
}
