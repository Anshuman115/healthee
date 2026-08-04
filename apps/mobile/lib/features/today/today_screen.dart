/// Today — what the strap measured, and what the server made of it.
///
/// ## Two sources, and neither may take the other down
///
/// The measured half comes from this phone's own store and renders with no
/// network at all (brief §7.4). The derived half comes from `/api/today`. They
/// are watched separately and fail separately, which is the whole reason the
/// screen is built this way:
///
///   * the server unreachable with nothing cached → the derived sections
///     collapse into ONE error card with a retry, and every measurement is still
///     on screen;
///   * the local store unreadable → that IS the screen failing, and it says so
///     with a retry rather than drawing a page of empty cards.
///
/// A page of twenty error cards would be the same news said twenty times, which
/// reads as breakage rather than as one connection problem.
///
/// ## `ListView.builder` and reveal-once
///
/// The list is a `ListView.builder` and the [RevealRegistry] lives in this
/// screen's `State`. Both halves are required and neither works alone: the
/// builder is what keeps a long list at 60 fps, and it is also precisely what
/// makes a chart's own `State` die on scroll and replay its animation on the way
/// back. `shared/reveal_once.dart` has the full argument, and every ported
/// painter takes its progress as a parameter for exactly this reason.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/widgets/connection_strip.dart';
import 'package:healthee/features/today/widgets/device_health_card.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The push state, for the data-health strip. Re-read whenever Today is.
final _pushStampProvider = FutureProvider<PushStamp>((ref) {
  return ref.watch(localStoreProvider).pushReader.lastAttempt();
});

/// The app's home screen.
class TodayScreen extends ConsumerStatefulWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const TodayScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// Outlives every list item, which is the whole reveal-once mechanism.
  final RevealRegistry _reveals = RevealRegistry();

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(todaySnapshotProvider);
    final push = ref.watch(_pushStampProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: Column(
        children: [
          // In the chrome, not in the list: a connection state that scrolls
          // away is one the owner cannot check when they need it.
          ConnectionStrip(now: widget.now),
          Expanded(
            child: AsyncView<DeviceDay>(
              value: ref.watch(deviceDayProvider),
              loadingLabel: "Reading today's measurements",
              errorMessage: "Couldn't read this phone's own store",
              onRetry: () => ref.invalidate(deviceDayProvider),
              builder: (context, day) => RefreshIndicator(
                onRefresh: _refresh,
                child: _TodayBody(
                  day: day,
                  server: server,
                  push: push.value,
                  reveals: _reveals,
                  now: widget.now,
                  onRetryServer: () => ref.invalidate(todaySnapshotProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pull-to-refresh runs a real sync, a push, and a re-read. New data earns a
  /// fresh reveal, which is the one thing that may reset the registry —
  /// scrolling never does.
  Future<void> _refresh() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
    ref
      ..invalidate(todaySnapshotProvider)
      ..invalidate(_pushStampProvider);
    _reveals.reset();
  }
}

/// The ordered sections. Composition only — every module is its own widget.
class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.day,
    required this.server,
    required this.reveals,
    required this.onRetryServer,
    this.push,
    this.now,
  });

  final DeviceDay day;
  final AsyncValue<TodayView> server;
  final PushStamp? push;
  final RevealRegistry reveals;
  final DateTime? now;
  final VoidCallback onRetryServer;

  @override
  Widget build(BuildContext context) {
    final sections = _sections();
    return ListView.builder(
      // Always scrollable, so pull-to-refresh works on a short or empty day.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Insets.lg),
      itemCount: sections.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.xl),
        child: sections[index],
      ),
    );
  }

  /// What to show, in order.
  ///
  /// A phone that has synced nothing AND has heard nothing from the server gets
  /// ONE honest empty card rather than twenty identical refusals — twenty of the
  /// same sentence reads as breakage, and the true statement is simply that the
  /// strap has not been read yet.
  List<Widget> _sections() {
    final view = server.value;
    if (day.hasNothing && view == null) {
      return [
        const EmptyState(
          message: 'Nothing from your strap yet',
          hint:
              'Tap "Sync now" above with the strap on your wrist and nearby. '
              'Everything on this screen comes off the device or from the '
              "server's reading of it; nothing is estimated in the meantime.",
        ),
        DeviceHealthCard(day: day, now: now),
        if (server.hasError) _serverError(),
      ];
    }
    return [
      // One card for the whole derived half when the server is unreachable, and
      // it sits where the derived sections would have started.
      if (view == null && server.hasError) _serverError(),
      if (view == null && server.isLoading)
        const LoadingState(label: "Reading the server's view of today"),
      ...todaySections(
        day: day,
        reveals: reveals,
        server: view,
        push: push,
        now: now,
      ),
    ];
  }

  /// The derived half is unreachable. Says which half, and offers the retry.
  ///
  /// A retry rather than a withheld card, because this is OUR failure and not an
  /// answer: `WithheldCard` never offers a retry precisely so the two cannot be
  /// confused.
  Widget _serverError() => ErrorState(
    message: "Couldn't reach your server for today's judgements",
    detail:
        'Your measurements below are on this phone and are unaffected. '
        'Recovery, sleep health, debt, VO₂max and biological age are worked out '
        'on the server, so they are not shown until it answers.',
    onRetry: onRetryServer,
  );
}
