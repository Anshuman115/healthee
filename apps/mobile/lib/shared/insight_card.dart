import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/data/insights/generated_insight.dart';
import 'package:healthee/data/insights/insight_repository.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/fold.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:solar_icons/solar_icons.dart';

/// What sits above an insight the server could not ground.
///
/// Public so a test can pin it. Wording matched to the coach thread's own line
/// for the same state, so the two surfaces do not describe one server outcome
/// two ways.
const String kUngroundedInsightNote =
    'The server could not ground this in its evidence base, so this is its '
    'honest fallback rather than an interpretation of your data.';

/// Lazy, collapsible server analysis, shared across legacy detail surfaces.
///
/// The analysis is model prose, so its sources are in the ⓘ on this card's own
/// head rather than in a chip row under the paragraphs — the rule
/// `shared/states/grounded_text.dart` states for every surface that draws
/// generated text. The dot appears once the analysis has been read and cited
/// something; a card still collapsed has nothing to ground.
class InsightCard extends ConsumerStatefulWidget {
  const InsightCard({
    required this.scope,
    this.target = '',
    this.title = 'Coach analysis',
    super.key,
  });
  final String scope;
  final String target;
  final String title;

  @override
  ConsumerState<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends ConsumerState<InsightCard> {
  bool _open = false;

  /// Whether this card has ever been opened.
  ///
  /// **The provider is not watched until the first open** — the endpoint is
  /// LLM-backed and allowance-gated, so a card that read it to decide whether
  /// to draw a 16px glyph would spend the owner's questions on scrolling past.
  /// After that first open it stays watched, because dropping the value on
  /// close leaves [Fold] with nothing to collapse and the card snaps shut
  /// instead of folding. Re-reading a provider already in the cache costs no
  /// request.
  bool _fetched = false;

  @override
  Widget build(BuildContext context) {
    final provider = generatedInsightProvider(widget.scope, widget.target);
    final insight = _fetched ? ref.watch(provider) : null;
    final panel = Panel(
      tone: Tone.fitness,
      label: widget.title,
      // **The same head, the same shut size, as `SleepAnalysisPanel`.** This
      // card used to be a `StateCard` around a Material `ListTile`, which
      // enforces its own minimum row height on top of the card's fixed
      // `Insets.lg` padding — so the two analysis cards folded to visibly
      // different sizes and the compactness had to be fixed twice. They are one
      // shape now, and a change to `Panel` moves both.
      head: PanelHead(
        title: widget.title,
        icon: SolarIconsOutline.stars,
        detail: _detail(insight?.value),
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
        child: Padding(
          padding: const EdgeInsets.only(top: Panel.headGap),
          child: insight == null
              ? const SizedBox.shrink()
              : AccountAsyncView<GeneratedInsight>(
                  value: insight,
                  onRetry: () => ref.invalidate(provider),
                  builder: (context, analysis) => analysis.text.isEmpty
                      ? const EmptyState(
                          message: 'No grounded analysis available yet',
                          hint:
                              'More observations may be needed before the '
                              'server can interpret this.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // The honest fallback and a refusal are OUR
                            // sentences, and they are shown. This line says
                            // which kind of sentence the reader is looking at,
                            // in the same treatment the coach thread gives an
                            // unvalidated reply, so a "we could not ground
                            // this" is not read as an interpretation of the
                            // owner's data.
                            if (!analysis.validated) ...<Widget>[
                              Text(
                                kUngroundedInsightNote,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                            ],
                            GroundedMarkdown(
                              text: analysis.text,
                              accent: context.colors.accent,
                            ),
                          ],
                        ),
                ),
        ),
      ),
    );
    // Shut, the whole card opens it; open, only the chevron closes it — a
    // card-wide target over the analysis would close it under a scrolling
    // finger. Same rule as `tail_panels.dart`'s.
    // **Always wrapped, never conditionally.** Returning `panel` when open and
    // `HTap(child: panel)` when shut changes the SHAPE of the tree between the
    // two states, so Flutter discards the subtree on every toggle — taking
    // `Fold`'s `State` and its `AnimationController` with it. The controller is
    // then recreated seeded at its resting value, which is exactly "no
    // animation". Constant shape, preserved state, and the fold runs.
    return HTap(onTap: _toggle, child: panel);
  }

  /// The vertical inset while the fold is shut. Matches `SleepAnalysisPanel`.
  static const double shutPadding = 11;

  /// Opens or closes it, arming the fetch the first time.
  void _toggle() => setState(() {
    _open = !_open;
    _fetched = _fetched || _open;
  });

  /// The analysis's own grounding: its inline markers, the payload's citations
  /// and the grade floor the server computed. Nothing before it has been read.
  MetricDetail _detail(GeneratedInsight? insight) =>
      insight == null || insight.text.isEmpty
      ? MetricDetail.none
      : MetricDetail.grounded(
          groundingOf(insight.text, alsoCites: insight.citations),
          grade: insight.gradeFloor,
          title: widget.title,
        );
}
