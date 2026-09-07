import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/data/insights/generated_insight.dart';
import 'package:healthee/data/insights/insight_repository.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = generatedInsightProvider(widget.scope, widget.target);
    // Watched only while open. The endpoint is LLM-backed and allowance-gated,
    // so a card that read it to decide whether to draw a 16 px glyph would
    // spend the owner's questions on scrolling past.
    final insight = _open ? ref.watch(provider) : null;
    return StateCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Flexible(child: Text(widget.title)),
                if (_detail(insight?.value) case final MetricDetail detail
                    when detail.isNotEmpty)
                  MetricInfoDot(
                    null,
                    detail: detail,
                    fallbackTitle: widget.title,
                  ),
              ],
            ),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _open = !_open),
          ),
          if (insight != null)
            AccountAsyncView<GeneratedInsight>(
              value: insight,
              onRetry: () => ref.invalidate(provider),
              builder: (context, analysis) => analysis.text.isEmpty
                  ? const EmptyState(
                      message: 'No grounded analysis available yet',
                      hint:
                          'More observations may be needed before the server can interpret this.',
                    )
                  : GroundedMarkdown(
                      text: analysis.text,
                      accent: context.colors.accent,
                    ),
            ),
        ],
      ),
    );
  }

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
