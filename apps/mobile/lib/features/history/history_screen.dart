import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/history/history_repository.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/history/history_series.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/current_account_value.dart';

/// Selectable metric and period, backed by the server's canonical daily series.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({this.initialMetric, super.key});
  final String? initialMetric;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late HistoryMetric _metric =
      HistoryMetric.values
          .where((m) => m.id == widget.initialMetric)
          .firstOrNull ??
      HistoryMetric.hrv;
  int _days = 90;

  @override
  Widget build(BuildContext context) {
    final provider = metricHistoryProvider(_metric, _days);
    return Scaffold(
      appBar: AppBar(title: const Text('Metric history')),
      body: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          children: [
            _metricPicker(),
            _periodPicker(),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: AsyncView<List<TrendPoint>>(
                value: currentAccountValue(ref.watch(provider)),
                onRetry: () => ref.invalidate(provider),
                builder: (context, points) => HistorySeries(
                  points: points,
                  unit: _metric.unit,
                  metric: _metric.id,
                  days: _days,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricPicker() => DropdownButton<HistoryMetric>(
    value: _metric,
    isExpanded: true,
    items: [
      for (final metric in HistoryMetric.values)
        DropdownMenuItem(value: metric, child: Text(metricName(metric.id))),
    ],
    onChanged: (metric) => setState(() => _metric = metric!),
  );

  Widget _periodPicker() => SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 30, label: Text('30 days')),
      ButtonSegment(value: 90, label: Text('90 days')),
      ButtonSegment(value: 365, label: Text('1 year')),
      ButtonSegment(value: 1825, label: Text('5 years')),
    ],
    selected: {_days},
    onSelectionChanged: (days) => setState(() => _days = days.single),
  );
}
