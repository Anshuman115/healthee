/// `/api/notable` — the days the server thought stood out, on demand.
///
/// **This kept its pre-v02 body on purpose.** It is grounded model prose with
/// citations attached, and rebuilding it in v02 chrome means rebuilding the
/// citation surface with it — a different piece of work from this screen's
/// geometry, and where a `[personal_finding:…]` marker would most easily start
/// leaking again. `insights_sections.dart` records the same call for
/// `FindingsSection`, and Today made it for `ActionsSection`.
///
/// What DID change is the container. A bare `ExpansionTile` between two v02
/// cards is a naked row with no ground under it, so the tile is stripped of its
/// own dividers and shape and sits inside a [Panel] — the section around it
/// looks like one screen, and the prose inside it is untouched.
///
/// It is collapsed until asked for, which is not decoration: `notableEvents`
/// is a separate, premium-gated, LLM-backed endpoint, and a screen that fetched
/// it on every build would spend the owner's allowance for scrolling past.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/data/insights/notable_event.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';
import 'package:healthee/shared/v02/panel.dart';

/// The days the server flagged, behind one tap.
class NotableEvents extends ConsumerWidget {
  /// Builds the panel.
  const NotableEvents({super.key});

  /// The prototype has no equivalent; this is the app's own name for the block.
  static const String title = 'Notable days';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Panel(
      tone: Tone.stress,
      child: Theme(
        // The tile's own dividers would draw a rule across the panel it is
        // inside, and its default shape would round a corner inside a rounded
        // corner. Both off; the panel is the container.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            title,
            style: TypeScale.panelTitle.copyWith(color: colors.ink),
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          children: <Widget>[_Events()],
        ),
      ),
    );
  }
}

class _Events extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return CachedAsyncView<List<NotableEvent>>(
      value: ref.watch(notableEventsProvider),
      onRetry: () => ref.invalidate(notableEventsProvider),
      builder: (context, events) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (events.isEmpty)
            Text(
              'No notable shifts found in the recent window.',
              style: TypeScale.panelNote.copyWith(color: colors.ink2),
            ),
          for (final event in events)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: <Widget>[
                  Flexible(child: Text('${event.label} · ${event.day}')),
                  // What the server's reading of this day cites. The row also
                  // pushes into the metric's history, so the dot is on the
                  // title rather than in `trailing`, where the tap would be
                  // competing with the row's own.
                  if (MetricDetail.grounded(
                        groundingOf(event.meaning, alsoCites: event.notes),
                        title: event.label,
                      )
                      case final MetricDetail detail when detail.isNotEmpty)
                    MetricInfoDot(
                      null,
                      detail: detail,
                      fallbackTitle: event.label,
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${event.value} · recent median '
                    '${event.median ?? 'unavailable'}',
                  ),
                  if (event.meaning.isNotEmpty)
                    GroundedMarkdown(
                      text: event.meaning,
                      accent: colors.accent,
                    ),
                ],
              ),
              onTap: () => unawaited(
                context.push(
                  '${Routes.history}?metric='
                  '${Uri.encodeComponent(event.metric)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
