/// Sleep — **legacy's Sleep tab, ported**.
///
/// `healthee-legacy/app/lib/ui/sleep_screen.dart`. Every section, in legacy's
/// order, at legacy's sizes; `sleep_sections.dart` is the list and each card is
/// its own file. What differs is what the owner decided may differ: the typeface,
/// the light/dark scaffolding, and the honesty wording — every field arrives as a
/// `Reading`, a withheld value renders as withheld with its reason, and every
/// citation resolves to a source name.
///
/// ## Its own screen, not the Today shell
///
/// `shared/instrument_screen.dart` is built on `/api/today` and this phone's
/// store. Sleep is built on `/api/sleep`, `/api/sleep/consistency` and
/// `/api/sleep/insight` — three reads that fail independently — which is legacy's
/// shape too (`data/providers.dart` gives each its own provider and its own
/// timeout). Bending the shared shell around a second payload would have made
/// every screen carry a source only one of them uses.
///
/// ## Reveal-once, and why the registry lives here
///
/// `CLAUDE.md`: *"Scrollable chart screens use `ListView.builder` + reveal-once
/// animation, or charts replay on every scroll."* The builder destroys an item's
/// element when it leaves the viewport, so "have I animated?" cannot live in the
/// chart. It lives in this `State`, and each section is handed the reveal's
/// progress rather than owning a ticker.
///
/// The reveal itself is legacy's: a fade with a 16 px rise
/// (`ui.dart:45` — `fadeIn` + `moveY(begin: 16, end: 0)`), driven by the same
/// progress the charts grow on, so a card and its chart arrive together.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/data/sleep_repository.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/features/sleep/sleep_sections.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/skeletons/sleep_skeleton.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The Sleep tab.
class SleepScreen extends ConsumerStatefulWidget {
  /// [now] is injected by tests so the night labels are deterministic.
  const SleepScreen({this.now, super.key});

  /// The instant "last night" is measured against.
  final DateTime? now;

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  /// Outlives every list item, which is the whole reveal-once mechanism.
  final RevealRegistry _reveals = RevealRegistry();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          // All three states, and each one scrolls, so pull-to-refresh works
          // while the screen is empty — which is exactly when it is reached for.
          // `AsyncView` is not used here only because legacy's loading state is
          // the content-shaped `SleepSkeleton` rather than a spinner.
          child: ref
              .watch(sleepPageProvider)
              .when(
                skipLoadingOnRefresh: true,
                loading: () => const SleepSkeleton(),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: _SleepList.padding,
                  children: <Widget>[
                    ErrorState(
                      message: "Couldn't reach your server for your sleep",
                      detail:
                          'Your nights are safe. This is a connection problem, '
                          'not a gap in them.',
                      onRetry: () => ref.invalidate(sleepPageProvider),
                    ),
                  ],
                ),
                data: (page) => _SleepList(
                  page: page,
                  // Soft: the regularity block feeds two cards and must never be
                  // able to take the measured half of the screen down with it.
                  consistency: ref.watch(sleepConsistencyProvider).value,
                  now: widget.now ?? DateTime.now(),
                  reveals: _reveals,
                ),
              ),
        ),
      ),
    );
  }

  /// Pull-to-refresh runs a real sync and re-reads all three payloads. New data
  /// earns a fresh reveal, which is the one thing that may reset the registry —
  /// scrolling never does.
  Future<void> _refresh() async {
    await ref.read(syncControllerProvider.notifier).syncNow();
    ref
      ..invalidate(sleepPageProvider)
      ..invalidate(sleepConsistencyProvider)
      ..invalidate(sleepInsightProvider);
    _reveals.reset();
  }
}

class _SleepList extends StatelessWidget {
  const _SleepList({
    required this.page,
    required this.consistency,
    required this.now,
    required this.reveals,
  });

  final SleepPage page;
  final SleepConsistency? consistency;
  final DateTime now;
  final RevealRegistry reveals;

  /// Legacy's `EdgeInsets.fromLTRB(18, 16, 18, 120)`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 16, 18, 120);

  @override
  Widget build(BuildContext context) {
    if (page.nights.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: const <Widget>[
          SizedBox(height: 200),
          EmptyState(
            message: 'No sleep recorded yet',
            hint: 'Wear the strap overnight and sync, and this fills in.',
          ),
        ],
      );
    }
    final sections = sleepSections(page: page, consistency: consistency, now: now);
    return ListView.builder(
      // Always scrollable, so pull-to-refresh works on a short screen.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Padding(
          padding: EdgeInsets.only(bottom: section.gap),
          child: RevealOnce(
            id: 'sleep.${section.id}',
            registry: reveals,
            builder: (context, progress) => _Rise(
              progress: progress,
              child: section.build(context, progress),
            ),
          ),
        );
      },
    );
  }
}

/// Legacy's reveal: fade in while rising 16 px. `ui.dart:45`.
class _Rise extends StatelessWidget {
  const _Rise({required this.progress, required this.child});

  final double progress;
  final Widget child;

  /// Legacy's `moveY(begin: 16, end: 0)`.
  static const double _travel = 16;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: progress.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(0, _travel * (1 - progress.clamp(0.0, 1.0))),
      child: child,
    ),
  );
}
