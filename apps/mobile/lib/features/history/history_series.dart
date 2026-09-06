import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/history/history_statistics.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/history/history_explorer.dart';
import 'package:healthee/shared/insight_card.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Chart plus dated values so every plotted observation is also accessible.
class HistorySeries extends StatelessWidget {
  const HistorySeries({
    required this.points,
    required this.unit,
    this.metric,
    this.days = 90,
    super.key,
  });
  final List<TrendPoint> points;
  final String unit;
  final String? metric;
  final int days;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyState(
        message: 'No observations in this period',
        hint:
            'Sync your strap or choose a longer period. Missing days are not zero.',
      );
    }
    return ListView.builder(
      itemCount: points.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _summary(context);
        if (index == points.length + 1) {
          return metric == null
              ? const SizedBox.shrink()
              : InsightCard(scope: 'metric', target: metric!);
        }
        final point = points[points.length - index];
        return ListTile(
          title: Text(point.date),
          trailing: Text('${point.value} $unit'),
        );
      },
    );
  }

  Widget _statistics() {
    final stats = HistoryStatistics(points.map((p) => p.value).toList());
    String number(double value) => value.toStringAsFixed(2);
    return Text(
      'Average ${number(stats.mean)} · median ${number(stats.median)} · '
      'min ${number(stats.minimum)} · max ${number(stats.maximum)} $unit\n'
      'First-to-last change: ${number(stats.change)} $unit',
    );
  }

  Widget _summary(BuildContext context) => StateCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${points.length} recorded days · $unit',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Insets.md),
        HistoryExplorer(points: points, days: days),
        _statistics(),
        Text('${points.first.date} — ${points.last.date}'),
        const SizedBox(height: Insets.sm),
        const Text(
          'Daily values from the server. The chart scales to this period; gaps are missing days. See the current metric card for interpretation and data confidence.',
        ),
      ],
    ),
  );
}
