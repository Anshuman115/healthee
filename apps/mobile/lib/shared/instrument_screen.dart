/// The shell every tab screen is built in: two sources, one list, one reveal.
///
/// ## Two sources, and neither may take the other down
///
/// The measured half comes from this phone's own store and renders with no
/// network at all (brief §7.4). The derived half comes from `/api/today`. They
/// are watched separately and fail separately, which is the whole reason the
/// screens are built this way:
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
/// widget's `State`. Both halves are required and neither works alone: the
/// builder is what keeps a long list at 60 fps, and it is also precisely what
/// makes a chart's own `State` die on scroll and replay its animation on the way
/// back. `shared/reveal_once.dart` has the full argument, and every ported
/// painter takes its progress as a parameter for exactly this reason.
///
/// **That registry is only worth anything while this `State` lives.** It used to
/// die on every tab switch, because each tab was its own page — so the rule held
/// inside a screen and was defeated between them. The tabs are branches of a
/// `StatefulShellRoute.indexedStack` now (`shared/app_shell.dart`), which is what
/// keeps this object alive across a round trip.
///
/// ## No bar here
///
/// This widget draws no bottom bar and takes no tab index. There is exactly one
/// `AppTabBar` in the app and the shell owns it; five screens each drawing their
/// own was five chances to disagree. The `Scaffold` stays because `/diagnostics`
/// renders this shell **outside** the tab shell and still needs a page.
///
/// ## No app bar, and that is legacy's shape rather than a saving
///
/// `design_reference/project/hh/screen_today.jsx` starts each scroll with its own
/// header — an eyebrow, a display-size title, a theme toggle. A Material `AppBar`
/// saying "Sleep" above a bottom bar whose Sleep tab is already lit is the same
/// word twice and 56 px of the first screen spent on it.
///
/// ## Why this is shared rather than five copies
///
/// Today, Sleep, Activity, Coach and Diagnostics all render a list of cards over
/// the same two sources with the same failure rules. Standards §1: second
/// occurrence = extract. The screens that use it are now composition only — a tab
/// index and an ordered list of sections — which is what §3 means by "a screen is
/// composition of small widgets, not one God-widget".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Everything a screen's section list is built from.
@immutable
class ScreenData {
  /// Handed to a [SectionsBuilder] on every rebuild.
  const ScreenData({
    required this.day,
    required this.server,
    required this.reveals,
    required this.onRetryServer,
    this.now,
  });

  /// What the strap measured, and its refusals.
  final DeviceDay day;

  /// What the server made of it — including its loading and error states, which
  /// a section list is sometimes the right place to render.
  final AsyncValue<TodayView> server;

  /// Where "this chart has already animated" is remembered. The screen's.
  final RevealRegistry reveals;

  /// Re-reads `/api/today`. Handed to [serverErrorCard] by whichever section
  /// list decides to draw one.
  final VoidCallback onRetryServer;

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  /// The server's payload, or null when it has not answered.
  TodaySnapshot? get snapshot => server.value?.snapshot;

  /// The one card the derived half collapses into when it cannot be reached.
  ///
  /// Null when the server answered or is still answering — a screen that drew
  /// this while a request was in flight would be calling a slow network a
  /// failure.
  PageSection? get serverFailure => server.value == null && server.hasError
      ? PageSection(serverErrorCard(onRetryServer))
      : null;

  /// The placeholder while the derived half is still in flight.
  PageSection? get serverPending => server.value == null && server.isLoading
      ? const PageSection(LoadingState(label: "Reading the server's view of today"))
      : null;
}

/// Builds the ordered sections for one render.
typedef SectionsBuilder = List<PageSection> Function(ScreenData data);

/// A tab screen: the frame, the two sources, the list.
class InstrumentScreen extends ConsumerStatefulWidget {
  /// [sections] decides everything the screen draws, in order.
  const InstrumentScreen({
    required this.sections,
    this.chrome,
    this.now,
    this.onRefreshed,
    super.key,
  });

  /// What to draw, in order.
  final SectionsBuilder sections;

  /// Drawn above the scroll and outside it. A connection state that scrolls away
  /// is one the owner cannot check when they need it.
  final Widget? chrome;

  /// [now] is injected by tests so the freshness labels are deterministic.
  final DateTime? now;

  /// Run after a pull-to-refresh, for anything a screen watches that this shell
  /// does not know about. Today re-reads its push stamp here.
  final VoidCallback? onRefreshed;

  @override
  ConsumerState<InstrumentScreen> createState() => _InstrumentScreenState();
}

class _InstrumentScreenState extends ConsumerState<InstrumentScreen> {
  /// Outlives every list item, which is the whole reveal-once mechanism.
  final RevealRegistry _reveals = RevealRegistry();

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(todaySnapshotProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.chrome case final Widget bar) bar,
            Expanded(
              child: AsyncView<DeviceDay>(
                value: ref.watch(deviceDayProvider),
                loadingLabel: "Reading today's measurements",
                errorMessage: "Couldn't read this phone's own store",
                onRetry: () => ref.invalidate(deviceDayProvider),
                builder: (context, day) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: _SectionList(
                    sections: widget.sections(
                      ScreenData(
                        day: day,
                        server: server,
                        reveals: _reveals,
                        now: widget.now,
                        onRetryServer: () => ref.invalidate(todaySnapshotProvider),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pull-to-refresh runs a real sync, a push, and a re-read. New data earns a
  /// fresh reveal, which is the one thing that may reset the registry —
  /// scrolling never does.
  Future<void> _refresh() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
    ref.invalidate(todaySnapshotProvider);
    widget.onRefreshed?.call();
    _reveals.reset();
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.sections});

  final List<PageSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Always scrollable, so pull-to-refresh works on a short or empty day.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, Insets.xxl),
      itemCount: sections.length,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: sections[index].gap),
        child: sections[index].child,
      ),
    );
  }
}

/// The derived half is unreachable. Says which half, and offers the retry.
///
/// A retry rather than a withheld card, because this is OUR failure and not an
/// answer: `WithheldCard` never offers a retry precisely so the two cannot be
/// confused. Shared because four screens draw the same card for the same reason.
Widget serverErrorCard(VoidCallback onRetry) => ErrorState(
  message: "Couldn't reach your server for today's judgements",
  detail:
      'Your measurements are on this phone and are unaffected. Recovery, sleep '
      'health, debt, VO₂max and biological age are worked out on the server, so '
      'they are not shown until it answers.',
  onRetry: onRetry,
);
