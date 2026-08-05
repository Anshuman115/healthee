/// The loud half of the connection surface — full width, above the scroll, and
/// **absent entirely** when there is nothing to say.
///
/// ```text
///   quiet   →  nothing here; ConnectionDot sits in the header row beside the date
///   loud    →  this: the link's line, the progress, every alert, and one action
/// ```
///
/// The two halves are two widgets in two places because they belong in two
/// places — a 7 px dot inside a Row and a full-bleed strip above the scroll — but
/// they are **one decision**: `ConnectionHealth.quiet`, computed in exactly one
/// place (`data/sync/connection_health.dart`) and read by both. Neither widget
/// may re-derive it, because a widget that could decide it for itself is a widget
/// that could decide it while something is wrong.
///
/// It lives above the scroll rather than in it for the reason the strip it
/// replaces did: a connection state that scrolls away is one the owner cannot
/// check when they need it. What changed is that it is no longer there when
/// there is nothing to check.
///
/// ## What the loud shape must always contain
///
/// * **Every alert**, in order, headline first. A fault the strip cannot draw is
///   a fault the owner never learns about, which is strictly worse than the
///   permanent bar this replaces.
/// * **The progress of a running sync.** A spinner that vanishes is how "did it
///   work?" becomes unanswerable, so `busy` opens the strip on its own even with
///   no alert beside it.
/// * **Stop, while busy.** The strap accepts one connection at a time and a sync
///   the owner cannot end is a phone they have to background to escape.
///
/// ## "Sync now" is no longer permanent, and that is the point
///
/// The strip carried that button forever, which is what made the strip
/// permanent. Pull-to-refresh already runs `SyncController.syncNow` — the
/// un-debounced, explicitly-asked-for path (`shared/instrument_screen.dart`) —
/// so the manual sync is native, discoverable and costs no chrome at all. The
/// button still exists, on the surface that appears when something is wrong,
/// which is the only time reaching for it is not something the owner could have
/// done by pulling down.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/shared/connection/connection_dot.dart';

/// The connection state, when there is a reason to take up the room.
class ConnectionStrip extends StatelessWidget {
  /// [health] is the classified state; [onRetry] starts a sync.
  const ConnectionStrip({
    required this.health,
    required this.onRetry,
    required this.onStop,
    super.key,
  });

  /// What is wrong, what is running, and whether it may be quiet.
  final ConnectionHealth health;

  /// Runs a sync now. The same un-debounced path pull-to-refresh uses.
  final VoidCallback onRetry;

  /// Asks a running sync to stop at its next phase boundary.
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (health.quiet) {
      // Not an empty container with padding — nothing at all. The dot in the
      // header row is the whole of the quiet state.
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: colors.chrome,
        border: Border(bottom: BorderSide(color: colors.line2, width: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ConnectionDot(live: health.live, semanticLabel: ''),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  health.report.headline,
                  style: text.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (health.busy)
                TextButton(onPressed: onStop, child: const Text('Stop'))
              else if (health.alerts.isNotEmpty)
                // "Sync now", not "Try again": the shared server-error card
                // already offers a "Try again" that re-fetches `/api/today`,
                // and two identically-labelled controls doing different things
                // on one screen is how an owner learns that neither means much.
                TextButton(onPressed: onRetry, child: const Text('Sync now')),
            ],
          ),
          if (health.progress case final progress?) ...[
            const SizedBox(height: Insets.sm),
            _Progress(fraction: progress.fraction),
          ],
          // How old the data is, then what is wrong, then what to do. All three,
          // always — a failure with no freshness hides how stale the screen has
          // gone, and freshness with no remedy is a problem nobody can act on.
          if (health.report.freshness case final String line)
            _Line(line, style: text.bodySmall?.copyWith(color: colors.ink2)),
          for (final alert in health.alerts) ...[
            if (!alert.statedInHeadline)
              _Line(
                alert.headline,
                style: text.bodyMedium?.copyWith(color: colors.ink),
              ),
            if (alert.detail case final String remedy)
              _Line(remedy, style: text.bodySmall?.copyWith(color: colors.ink2)),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Insets.xs),
    child: Text(text, style: style),
  );
}

/// A determinate bar, only ever fed a fraction the fetcher actually reported.
class _Progress extends StatelessWidget {
  const _Progress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 3,
        backgroundColor: colors.line2,
        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
      ),
    );
  }
}
