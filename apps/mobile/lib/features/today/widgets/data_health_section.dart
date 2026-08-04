/// The freshness strip — the owner-facing operational view, and it matters.
///
/// Brief §5.8: *"production has served stale data behind a healthy-looking
/// screen before. The strip must make 'this number is 85 hours old' impossible
/// to miss without being alarming."*
///
/// Three facts live here and they are genuinely different:
///
/// ```text
///   feeds        which streams have gone quiet, and for how long
///   provenance   whether this whole payload came off disk, and when
///   backlog      how much the phone is holding that the server has not seen
/// ```
///
/// The first is the server's view of what it received; the second and third are
/// this phone's view of what it sent. A screen that showed only the first would
/// look perfectly healthy on a phone whose push has been failing for a week —
/// the server's feeds *are* fresh, up to the last thing it heard.
///
/// It renders nothing when all three are quiet. That silence is what makes it
/// worth reading when it speaks.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/data_health.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// What is stale, what is cached, and what has not been sent.
class DataHealthSection extends StatelessWidget {
  /// Any of [health], [push] or [cachedAt] may be null; the card renders only
  /// what it actually has something to say about.
  const DataHealthSection({
    this.health,
    this.push,
    this.cachedAt,
    this.cachedDate,
    this.now,
    super.key,
  });

  /// Per-feed freshness from the server.
  final DataHealth? health;

  /// This phone's push state.
  final PushStamp? push;

  /// When the payload on screen was received, if it came from the cache.
  final DateTime? cachedAt;

  /// Which day that cached payload describes, when it is not today's.
  final String? cachedDate;

  /// The current instant, injected so tests do not read the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final at = now ?? DateTime.now();
    final feeds = health?.degraded ?? const [];
    final lines = _lines(at);
    if (feeds.isEmpty && lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data health', style: text.labelSmall),
          for (final line in lines) ...[
            const SizedBox(height: Insets.sm),
            Text(line, style: text.bodyMedium?.copyWith(color: colors.ink)),
          ],
          if (feeds.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            for (final feed in feeds)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: _FeedRow(feed: feed),
              ),
          ],
        ],
      ),
    );
  }

  /// The sentences that are true right now. Empty means nothing to say.
  List<String> _lines(DateTime at) {
    return <String>[
      if (cachedAt case final DateTime received)
        cachedDate == null
            ? 'Showing the last snapshot the server sent, '
                  '${ageLabel(received, now: at)}.'
            : 'Showing the last snapshot the server sent — it describes '
                  '$cachedDate, ${ageLabel(received, now: at)}.',
      if (push?.failureReason case final String reason)
        "The last attempt to send your data didn't finish: $reason",
      if ((push?.pendingRows ?? 0) > 0)
        '${push!.pendingRows} measurements are waiting here to reach the '
            'server. Nothing is lost; they go out on the next sync.',
    ];
  }
}

/// One quiet feed: what it is, and how long it has been quiet.
class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.feed});

  final FeedHealth feed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        // A thin left mark rather than a tinted row: brief §2 puts state accents
        // on a border, never on a nested container.
        Container(width: 2, height: 22, color: colors.unf),
        const SizedBox(width: Insets.md),
        Expanded(child: Text(feed.label, style: text.titleSmall)),
        Text(
          _age(feed),
          style: text.labelMedium?.copyWith(color: colors.ink2),
        ),
      ],
    );
  }

  /// "Nothing has synced in 85 hours" is the brief's own example, and the hours
  /// are the load-bearing part — a status word alone hides the scale.
  static String _age(FeedHealth feed) {
    final hours = feed.ageHours;
    if (hours == null) {
      return 'never';
    }
    return hours < 48
        ? '${hours.round()} h ago'
        : '${(hours / 24).floor()} d ago';
  }
}
