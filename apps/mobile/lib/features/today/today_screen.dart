/// Today — what the strap measured, and what it cannot tell you on its own.
///
/// ## The order, and where it departs from the brief
///
/// `docs/APP_DESIGN_BRIEF.md` §4.1 orders Today by **what the owner should act
/// on**: illness flag, recovery, today's action, sleep, anomalies, metric strip,
/// data health. Five of those seven are server-derived and are withheld on this
/// build, so following the list literally would put five refusals above the
/// first real number and bury the measurements under an apology.
///
/// So the ORDERING PRINCIPLE is kept and the list is not: act-on-able first.
/// Steps, heart rate, sleep and sessions are things the owner can read and act
/// on today; the server's judgements come next, grouped and explained once
/// rather than scattered; device and sync health closes, as §5.8 asks. When the
/// derived numbers arrive they move up into the brief's own order, and the
/// section widget they live in is already the thing that would move.
///
/// ## `ListView.builder` and reveal-once
///
/// The list is a `ListView.builder` and the [RevealRegistry] lives in this
/// screen's `State`. Both halves are required and neither works alone: the
/// builder is what keeps a long list at 60 fps, and it is also precisely what
/// makes a chart's own `State` die on scroll and replay its animation on the way
/// back. `shared/reveal_once.dart` has the full argument.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/features/today/widgets/connection_strip.dart';
import 'package:healthee/features/today/widgets/device_health_card.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/metric_strip.dart';
import 'package:healthee/features/today/widgets/server_derived_card.dart';
import 'package:healthee/features/today/widgets/sleep_card.dart';
import 'package:healthee/features/today/widgets/steps_card.dart';
import 'package:healthee/features/today/widgets/workouts_card.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

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
                child: _TodayBody(day: day, reveals: _reveals, now: widget.now),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pull-to-refresh runs a real sync. New data earns a fresh reveal, which is
  /// the one thing that may reset the registry — scrolling never does.
  Future<void> _refresh() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
    _reveals.reset();
  }
}

/// The ordered sections. Composition only — every module is its own widget.
class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.day, required this.reveals, this.now});

  final DeviceDay day;
  final RevealRegistry reveals;
  final DateTime? now;

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
  /// A phone that has synced nothing gets ONE honest empty card rather than
  /// nine identical refusals — nine of the same sentence reads as breakage, and
  /// the true statement is simply that the strap has not been read yet.
  List<Widget> _sections() {
    if (day.hasNothing) {
      return [
        const EmptyState(
          message: 'Nothing from your strap yet',
          hint:
              'Tap "Sync now" above with the strap on your wrist and nearby. '
              'Everything on this screen comes off the device; nothing is '
              'estimated in the meantime.',
        ),
        DeviceHealthCard(day: day, now: now),
        ServerDerivedSection(day: day),
      ];
    }
    return [
      StepsCard(day: day, now: now),
      HeartRateCard(day: day, reveals: reveals, now: now),
      SleepCard(day: day, now: now),
      WorkoutsCard(workouts: day.workouts),
      MetricStrip(metrics: day.metrics, now: now),
      ServerDerivedSection(day: day),
      DeviceHealthCard(day: day, now: now),
    ];
  }
}
