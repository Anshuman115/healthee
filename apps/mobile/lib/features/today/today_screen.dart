/// Today — what the strap measured, and what the server made of it.
///
/// Composition only. The frame, the two data sources, the failure rules and the
/// reveal registry all live in `shared/instrument_screen.dart`, which four other
/// screens use for the same reasons; `today_sections.dart` decides what Today
/// shows and in what order. This file is the wiring between them plus the two
/// things only Today watches — the push stamp and the server session.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/widgets/connection_strip.dart';
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
    final push = ref.watch(_pushStampProvider).value;
    // `.value?.signedIn` and not `.requireValue`: while the keystore read is in
    // flight this is null, which the data-health strip reads as "not yet known"
    // and stays silent about. Guessing "signed out" for a frame would flash an
    // invitation at an owner who already is.
    final signedIn = ref.watch(serverSessionProvider).value?.signedIn;
    return InstrumentScreen(
      now: now,
      // In the chrome, not in the list: a connection state that scrolls away is
      // one the owner cannot check when they need it.
      chrome: ConnectionStrip(now: now),
      onRefreshed: () => ref.invalidate(_pushStampProvider),
      sections: (data) => todaySections(
        data,
        TodayExtras(
          push: push,
          signedIn: signedIn,
          onSignIn: () => context.go(Routes.serverSignIn),
          onOpen: context.go,
        ),
      ),
    );
  }
}
