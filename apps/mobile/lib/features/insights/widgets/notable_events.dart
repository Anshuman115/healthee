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
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/data/insights/notable_event.dart';
import 'package:healthee/shared/format/date_labels.dart';
import 'package:healthee/shared/format/number_labels.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';
import 'package:healthee/shared/v02/fold.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';

/// The days the server flagged, behind one tap.
class NotableEvents extends StatefulWidget {
  /// Builds the panel.
  const NotableEvents({super.key});

  /// The prototype has no equivalent; this is the app's own name for the block.
  static const String title = 'Notable days';

  @override
  State<NotableEvents> createState() => _NotableEventsState();
}

/// ## ⛔ Not `ExpansionTile` — that was a third way of folding
///
/// This panel used Material's own tile, with Material's chevron, Material's
/// timing and a `Theme` override to switch off the divider and the corner it
/// would otherwise draw inside the panel's own. Meanwhile the two analysis
/// cards fold with [Fold] and `PanelHead`'s chevron. One gesture, three
/// behaviours, and the owner had already asked for them to match.
///
/// It folds like the analysis cards now: the same chevron, the same 160ms
/// `Align.heightFactor` reveal, the same whole-card tap while shut, and the
/// same shut inset — so a change to `Panel` moves all three.
class _NotableEventsState extends State<NotableEvents> {
  /// The vertical inset while the fold is shut. Matches the analysis cards.
  static const double shutPadding = 11;

  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final panel = Panel(
      tone: Tone.stress,
      label: NotableEvents.title,
      head: PanelHead(
        title: NotableEvents.title,
        collapsed: !_open,
        onToggle: _toggle,
      ),
      headSpacing: 0,
      padded: EdgeInsets.symmetric(
        horizontal: Panel.padding,
        vertical: _open ? Panel.padding : shutPadding,
      ),
      child: Fold(
        open: _open,
        child: const Padding(
          padding: EdgeInsets.only(top: Panel.headGap),
          child: _Events(),
        ),
      ),
    );
    // **Always wrapped, never conditionally.** Returning `panel` when open and
    // `HTap(child: panel)` when shut changes the SHAPE of the tree between the
    // two states, so Flutter discards the subtree on every toggle — taking
    // `Fold`'s `State` and its `AnimationController` with it. The controller is
    // then recreated seeded at its resting value, which is exactly "no
    // animation". Constant shape, preserved state, and the fold runs.
    return HTap(onTap: _toggle, child: panel);
  }

  void _toggle() => setState(() => _open = !_open);
}

class _Events extends ConsumerWidget {
  const _Events();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return CachedAsyncView<List<NotableEvent>>(
      value: ref.watch(notableEventsProvider),
      onRetry: () => ref.invalidate(notableEventsProvider),
      builder: (context, events) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (events.isEmpty)
            Text(
              'No notable shifts found in the recent window.',
              style: TypeScale.panelNote.copyWith(color: colors.ink2),
            ),
          for (final (int i, NotableEvent event) in events.indexed)
            _EventRow(event: event, first: i == 0),
        ],
      ),
    );
  }
}

/// One notable day: what moved, when, by how much against its own median.
///
/// ## What this replaced
///
/// A Material `ListTile` printing `'${event.label} · ${event.day}'` and
/// `'${event.value} · recent median ${event.median}'` — so the card read as
/// stacked paragraphs of raw fields: the ISO day (`2026-09-05`) where every
/// other surface in this app says `5 Sep`, and undivided doubles
/// (`3694.6`, `11456.0`) where `decimalLabel` exists precisely because *"a
/// calorie total of 2,140.0 is a tenth nobody measured"*.
///
/// ⚠ **The prose inside `meaning` is still the server's**, and it carries the
/// same two habits: *"On 2026-09-05, total calories were elevated at 3,694.6
/// kcal…"*. That is a sentence this client must not rewrite — munging server
/// prose to reformat a number is how a meaning gets corrupted by a regex. It
/// belongs in `read/`'s own wording.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.first});

  static const double rowPad = 12;

  final NotableEvent event;
  final bool first;

  /// What the server's reading of this day cites.
  MetricDetail get _detail => MetricDetail.grounded(
    groundingOf(event.meaning, alsoCites: event.notes),
    title: event.label,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final median = event.median;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!first)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: rowPad),
            child: SizedBox(
              height: hairline,
              child: ColoredBox(color: colors.line),
            ),
          )
        else
          const SizedBox(height: rowPad),
        HTap(
          onTap: () => unawaited(
            context.push(
              '${Routes.history}?metric='
              '${Uri.encodeComponent(event.metric)}',
            ),
          ),
          semanticLabel: '${event.label}, ${shortDate(event.day)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      event.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.panelTitle.copyWith(color: colors.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    shortDate(event.day),
                    style: TypeScale.tinyLabel.copyWith(color: colors.ink3),
                  ),
                  if (_detail case final MetricDetail detail
                      when detail.isNotEmpty)
                    MetricInfoDot(
                      null,
                      detail: detail,
                      fallbackTitle: event.label,
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    decimalLabel(event.value),
                    style: TypeScale.panelContext.copyWith(
                      color: context.family,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      // Null median is said in words, never as a blank or a
                      // zero: "we have no median for this" and "the median is
                      // nothing" are different claims.
                      median == null
                          ? 'no recent median to compare'
                          : 'median ${decimalLabel(median)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.tinyLabel.copyWith(color: colors.ink3),
                    ),
                  ),
                ],
              ),
              if (event.meaning.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                GroundedMarkdown(text: event.meaning, accent: colors.accent),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
