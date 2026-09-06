import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/insights/notable_event.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';

class NotableEvents extends ConsumerWidget {
  const NotableEvents({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpansionTile(
    title: const Text('Notable events'),
    children: [
      CachedAsyncView<List<NotableEvent>>(
        value: ref.watch(notableEventsProvider),
        onRetry: () => ref.invalidate(notableEventsProvider),
        builder: (context, events) => Column(
          children: [
            if (events.isEmpty)
              const Text('No notable shifts found in the recent window.'),
            for (final event in events)
              ListTile(
                title: Text('${event.label} · ${event.day}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.value} · recent median ${event.median ?? 'unavailable'}',
                    ),
                    if (event.meaning.isNotEmpty)
                      GroundedMarkdown(
                        text: event.meaning,
                        alsoCites: event.notes,
                        accent: context.colors.accent,
                      ),
                  ],
                ),
                onTap: () => unawaited(
                  context.push(
                    '${Routes.history}?metric=${Uri.encodeComponent(event.metric)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
