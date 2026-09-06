import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/insights/generated_insight.dart';
import 'package:healthee/data/insights/insight_repository.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Lazy, collapsible server analysis, shared across legacy detail surfaces.
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
  Widget build(BuildContext context) => StateCard(
    child: Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.title),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open) _analysis(),
      ],
    ),
  );

  Widget _analysis() {
    final provider = generatedInsightProvider(widget.scope, widget.target);
    return AccountAsyncView<GeneratedInsight>(
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      builder: (context, insight) => insight.text.isEmpty
          ? const EmptyState(
              message: 'No grounded analysis available yet',
              hint:
                  'More observations may be needed before the server can interpret this.',
            )
          : GroundedMarkdown(
              text: insight.text,
              alsoCites: insight.citations,
              grade: insight.gradeFloor,
              accent: context.colors.accent,
            ),
    );
  }
}
