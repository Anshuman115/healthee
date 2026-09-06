import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/journal/journal_entry.dart';
import 'package:healthee/data/journal/journal_feed.dart';
import 'package:healthee/data/journal/journal_repository.dart';
import 'package:healthee/data/journal/log_kind.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/current_account_value.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Current state is fetched, never inferred from a failed start/end request.
class JournalRecent extends ConsumerWidget {
  const JournalRecent({required this.busy, required this.onFast, super.key});
  final bool busy;
  final void Function({required bool end}) onFast;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => CachedAsyncView<JournalFeed>(
    value: currentAccountValue(ref.watch(journalFeedProvider)),
    onRetry: () => ref.invalidate(journalFeedProvider),
    builder: (context, feed) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton(
          onPressed: busy ? null : () => onFast(end: feed.fastOpen),
          child: Text(feed.fastOpen ? 'End fast' : 'Record start of a fast'),
        ),
        if (feed.fastOpen && feed.fastMinutes != null)
          Text('${feed.fastMinutes} minutes at last refresh'),
        Text('Recent entries', style: Theme.of(context).textTheme.titleMedium),
        TextButton(
          onPressed: () => ref.invalidate(journalFeedProvider),
          child: const Text('Refresh recent entries'),
        ),
        if (feed.entries.isEmpty)
          const EmptyState(
            message: 'No recent entries',
            hint: 'Your saved observations appear here.',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: feed.entries.length,
            itemBuilder: (context, index) => _entry(feed.entries[index]),
          ),
      ],
    ),
  );

  Widget _entry(JournalEntry entry) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(entry.name ?? _label(entry.type)),
    subtitle: Text(
      '${entry.at.toLocal()}${entry.notes == null ? '' : '\n${entry.notes}'}',
    ),
    trailing: entry.amount == null
        ? null
        : Text('${entry.amount} ${entry.unit ?? ''}'),
  );

  String _label(String type) =>
      LogKind.values.where((kind) => kind.name == type).firstOrNull?.label ??
      type;
}
