/// `Your moments` — the recent entries, as `.list-row`s.
///
/// ```js
/// // screens-actions.js
/// H.section('Your recent moments',
///   `<div class="card flush">${journalEntries()}</div>`)
/// // each row: H.row(icon, kind, `${value} ${unit} · ${time}`, 'journal')
/// ```
///
/// **Current fasting state is fetched, never inferred.** The feed says whether a
/// fast is open; this widget does not decide it from whether a start request
/// appeared to succeed. That is the rule the file was written under and the
/// redesign does not touch it — only what the rows look like.
///
/// A feed with no entries draws the empty state and **no heading of its own**:
/// the heading belongs to the screen, which is what decides whether to draw one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/journal/journal_entry.dart';
import 'package:healthee/data/journal/journal_feed.dart';
import 'package:healthee/data/journal/journal_repository.dart';
import 'package:healthee/data/journal/log_kind.dart';
import 'package:healthee/features/journal/v02/journal_grid.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/current_account_value.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/rows.dart';

/// The recent entries, and the running fast when there is one.
class JournalRecent extends ConsumerWidget {
  /// [now] is injected by tests so the relative times are deterministic.
  const JournalRecent({this.now, super.key});

  /// The instant "3 h ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CachedAsyncView<JournalFeed>(
      value: currentAccountValue(ref.watch(journalFeedProvider)),
      onRetry: () => ref.invalidate(journalFeedProvider),
      builder: (context, feed) => _Feed(feed: feed, now: now),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed({required this.feed, required this.now});

  final JournalFeed feed;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final at = now ?? DateTime.now();
    if (feed.entries.isEmpty && !feed.fastOpen) {
      return const EmptyState(
        message: 'No recent entries',
        hint: 'Your saved observations appear here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (feed.fastOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              feed.fastMinutes == null
                  ? 'A fast is running.'
                  : 'A fast is running · ${feed.fastMinutes} minutes at the '
                        'last refresh.',
              style: TypeScale.small.copyWith(color: colors.ink2),
            ),
          ),
        RowCard(<Widget>[
          for (final entry in feed.entries)
            ListRow(
              icon: iconFor(entry.type),
              title: entry.name ?? labelFor(entry.type),
              subtitle: line(entry, at),
              tone: Tone.fitness,
            ),
        ]),
      ],
    );
  }

  /// `80 mg · 3 h ago`, out of whichever parts the entry carries.
  static String line(JournalEntry entry, DateTime now) {
    final amount = entry.amount;
    final parts = <String>[
      if (amount != null)
        '${amount == amount.roundToDouble() ? amount.round() : amount}'
            '${entry.unit == null ? '' : ' ${entry.unit}'}',
      ageLabel(entry.at, now: now),
      if (entry.notes case final String notes) notes,
    ];
    return parts.join(' · ');
  }

  /// The tile glyph for a type, so a row and its tile cannot disagree.
  static IconData iconFor(String type) {
    for (final tile in kJournalTiles) {
      if (tile.kind?.name == type) {
        return tile.icon;
      }
    }
    return Icons.edit_note;
  }

  /// The enum's own label, or the raw type when this build has never heard of
  /// it — inventing a name for a type the server grew would hide that.
  static String labelFor(String type) =>
      LogKind.values.where((kind) => kind.name == type).firstOrNull?.label ??
      type;
}
